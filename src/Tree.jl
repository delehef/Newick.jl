mutable struct Node{T}
    children::Vector{Int}
    parent::Int
    pl::T
end

mutable struct Tree{T}
    _nodes::Dict{Int, Node{T}}
end
Tree{T}() where T = Tree{T}(Dict())

Base.getindex(t::Tree, i::Int) = return t._nodes[i]
Base.keys(t::Tree) = keys(t._nodes)
Base.show(io::IO, t::Tree) = print(io, prettyprint(t))
nodes(t::Tree) = t._nodes
parent(t::Tree, n::Int)  = t[n].parent
children(t::Tree, n::Int) = t[n].children
function maptree!(f, t::Tree)
    for n in keys(t._nodes)
        t[n].pl = f(t[n].pl)
    end
end

isroot(t::Tree, n) = t[n].parent == 0
isleaf(t::Tree, n) = isempty(t._nodes[n].children)

leaves(t::Tree) = filter(n -> isleaf(t, n), keys(t._nodes))

function add_node(t::Tree{T}, value::T; parent::Int = 0, id::Union{Int, Nothing} = nothing) where T
    _id = something(id, isempty(keys(t._nodes)) ? 1 : (maximum(keys(t._nodes)) + 1))
    @assert _id ∉ keys(t._nodes)
    @assert parent == 0 || parent ∈ keys(t._nodes)
    t._nodes[_id] = Node{T}(Int[], parent, value)
    parent ≠ 0 && push!(t._nodes[parent].children, _id)
    return _id
end

function plug!(t::Tree, target::Int, n::Int)
    @assert n ∉ t._nodes[target].children

    t._nodes[n].parent = target
    push!(t._nodes[target].children, n)
end

function unplug!(t::Tree, n::Int)
    parent = t._nodes[n].parent
    @assert(parent == 0 || n ∈ t._nodes[parent].children)
    t._nodes[n].parent = 0
    parent ≠ 0 && filter!(.≠(n), t._nodes[parent].children)
end

function unplug!(t::Tree, parent::Int, ns::A) where A <: AbstractArray{Int}
    for n in ns
        @assert(n ∈ t._nodes[parent].children)
        t._nodes[n].parent = 0
    end
    filter!(.!∈(ns), t._nodes[parent].children)
end

function delete_node!(t::Tree, n::Int)
    @assert n ∈ keys(t._nodes)

    unplug!(t, n)
    delete!(t._nodes, n)
end

function delete_nodes!(t::Tree, ns::T)  where T <: AbstractArray{Int}
    for n in ns
        delete_node!(t, n)
    end
end


function move!(t::Tree, n::Int, dest::Int)
    unplug!(t, n)
    plug!(t, dest, n)
end

function ascendance(t::Tree, n::Int)
    x = n
    r = [n]
    while t[x].parent ≠ 0
        x = t[x].parent
        push!(r, x)
    end
    return r
end

function descendants(t::Tree, n)
    function rec_descendants(i, ax)
        append!(ax, t._nodes[i].children)
        for j in t._nodes[i].children
            rec_descendants(j, ax)
        end
    end

    r = []
    rec_descendants(n, r)
    return r
end

function descendant_leaves(t::Tree, n)
    function rec_descendants(i, ax)
        if isleaf(t, i)
            push!(ax, i)
        else
            for j in t._nodes[i].children
                rec_descendants(j, ax)
            end
        end
    end

    r = []
    rec_descendants(n, r)
    return r
end

function topo_depth(t::Tree, n::Int; state = 0)
    if t[n].parent == 1
        state
    else
        topo_depth(t, t[n].parent; state=state+1)
    end
end

function mrca(t::Tree, nodes::A) where A <: AbstractSet{Int}
    isempty(nodes) && return 0
    length(nodes) == 1 && return first(nodes)

    ancestries = [ascendance(t, n)[2:end] for n in nodes]
    for a in ancestries[1]
        if all([a ∈ ancestry for ancestry in ancestries[2:end]])
            return a
        end
    end

    return 0
end

function prettyprint(t::Tree; start=1)
    function rec_disp(i, depth)
        println(' '^depth, t[i].pl)

        for j in t._nodes[i].children
            rec_disp(j, depth + 2)
        end
    end

    rec_disp(start, 0)
end

function tonewick(tree::Tree)
    function fmtTree(i::Int)::String
        r = IOBuffer()
        if !isempty(tree[i].children)
            cs = join(filter(x -> !isempty(x), map(c -> fmtTree(c), tree[i].children)), ",")
            print(r, "(", cs, ")", "\n")
        end
        print(r, tree[i].pl)
        return String(take!(r))
    end

    return fmtTree(1) * ";"
end
