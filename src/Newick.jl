module Newick
using Lerche

include("Tree.jl")

newick_grammar = raw"""
%import common.SIGNED_NUMBER -> NUMBER

%import common.WS
%ignore WS

tree:      node ";"
?node:      leaf | clade
leaf:       name attributes?
clade:      "(" node? ("," node?)* ")" name? attributes?
attributes: length | _nhx | length _nhx
_nhx:       "[&&NHX" nhxentry+ "]"
nhxentry:   ":" nhxkey "=" nhxvalue
length:     ":" NUMBER

nhxkey:   /[^:,;()\[\]=]+/
nhxvalue: /[^:,;()\[\]=]+/
name:     /[^:,;()\[\]]+/
"""

mutable struct NewickNode
    name :: String
    length :: Float32
    attrs :: Dict{String, String}
    NewickNode() = new("", 0.0, Dict())
end
Base.show(io::IO, n::NewickNode) = print(io, "$(n.name)")

struct TreeToNewick <: Transformer end

@inline_rule nhxkey(t :: TreeToNewick, k) = string(k[1])
@inline_rule nhxvalue(t :: TreeToNewick, v) = string(v[1])
@inline_rule name(t :: TreeToNewick, s) = (:name, string(s))
@rule length(t :: TreeToNewick, n) = (:length, Base.parse(Float64, n[1]))
@rule nhxentry(t :: TreeToNewick, nhx) = (:nhxentry, nhx)
@rule attributes(t :: TreeToNewick, a) = (:attributes, a)
@rule clade(t :: TreeToNewick, c) = (:clade, c)
@rule leaf(t :: TreeToNewick, l) = (:leaf, l)
@rule node(t :: TreeToNewick, n) = (:node, n)
@rule tree(t :: TreeToNewick, tt) = tt[1]
# @rule nhx(t :: TreeToNewick, n) = n[2]



newick_parser = Lark(newick_grammar, parser="lalr", lexer="contextual", start="tree", transformer=TreeToNewick(), debug=false)

function fromstr(text :: String)
    function parse_node(parent :: Int, tree :: Tree{NewickNode}, n)
        my_id = add_node(tree, NewickNode(); parent=parent)

        for c in n[2]
            if c[1] == :clade || c[1] == :leaf
                parse_node(my_id, tree, c)
            elseif c[1] == :name
                tree[my_id].pl.name = c[2]
            elseif c[1] == :length
                tree[my_id].tag.length = c[2]
            elseif c[1] == :attributes
                for a in c[2]
                    if a[1] == :length
                        tree[my_id].pl.length = a[2]
                    elseif a[1] == :nhxentry
                        tree[my_id].pl.attrs[a[2][1]] = a[2][2]
                    else
                        @warn a
                    end
                end
            else
                @warn c
            end
        end
    end

    tree = Tree{NewickNode}()
    parse_node(0, tree, Lerche.parse(newick_parser, text))
    return tree
end

function fromfilename(filename :: String)
    return fromstr(read(filename, String))
end
end
