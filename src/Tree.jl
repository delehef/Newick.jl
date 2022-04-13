const NodeID = Int;

mutable struct Node{T}
    children::Vector{NodeID}
    parent::NodeID
    pl::T
end

mutable struct Tree{T}
    _nodes::Dict{NodeID, Node{T}}
    _spans::Dict{NodeID, Vector{NodeID}}
end
Tree{T}() where T = Tree{T}(Dict(), Dict())

Base.getindex(t::Tree, i::NodeID) = return t._nodes[i]
Base.keys(t::Tree) = keys(t._nodes)
Base.show(io::IO, t::Tree) = print(io, prettyprint(t))
nodes(t::Tree) = t._nodes
parent(t::Tree, n::NodeID)  = t[n].parent
children(t::Tree, n::NodeID) = t[n].children
function maptree!(f, t::Tree)
    for n in keys(t._nodes)
        t[n].pl = f(t[n].pl)
    end
end

cached_span(t::Tree, n::NodeID) = t._spans[n]
function cache_spans(t::Tree)
    for k in keys(t._nodes)
        t._spans[k] = descendant_leaves(t, k)
    end
end


isroot(t::Tree, n) = t[n].parent == 0
isleaf(t::Tree, n) = isempty(t._nodes[n].children)

leaves(t::Tree) = filter(n -> isleaf(t, n), keys(t._nodes))

function add_node(t::Tree{T}, value::T; parent::NodeID = 0, id::Union{NodeID, Nothing} = nothing) where T
    _id = something(id, isempty(keys(t._nodes)) ? 1 : (maximum(keys(t._nodes)) + 1))
    @assert _id ∉ keys(t._nodes)
    @assert parent == 0 || parent ∈ keys(t._nodes)
    t._nodes[_id] = Node{T}(NodeID[], parent, value)
    parent ≠ 0 && push!(t._nodes[parent].children, _id)
    return _id
end

function plug!(t::Tree, target::NodeID, n::NodeID)
    @assert n ∉ t._nodes[target].children

    t._nodes[n].parent = target
    push!(t._nodes[target].children, n)
end

function unplug!(t::Tree, n::NodeID)
    parent = t._nodes[n].parent
    @assert(parent == 0 || n ∈ t._nodes[parent].children)
    t._nodes[n].parent = 0
    parent ≠ 0 && filter!(.≠(n), t._nodes[parent].children)
end

function unplug!(t::Tree, parent::NodeID, ns::A) where A <: AbstractArray{NodeID}
    for n in ns
        @assert(n ∈ t._nodes[parent].children)
        t._nodes[n].parent = 0
    end
    filter!(.!∈(ns), t._nodes[parent].children)
end

function delete_node!(t::Tree, n::NodeID)
    @assert n ∈ keys(t._nodes)

    unplug!(t, n)
    delete!(t._nodes, n)
end

function delete_nodes!(t::Tree, ns::T)  where T <: AbstractArray{NodeID}
    for n in ns
        delete_node!(t, n)
    end
end


function move!(t::Tree, n::NodeID, dest::NodeID)
    unplug!(t, n)
    plug!(t, dest, n)
end

function ascendance(t::Tree, n::NodeID)
    x = n
    r = []
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
    function rec_descendants(i :: NodeID, ax :: Vector{NodeID})
        if isleaf(t, i)
            push!(ax, i)
        else
            for j in t._nodes[i].children
                rec_descendants(j, ax)
            end
        end
    end

    r = Vector{NodeID}()
    sizehint!(r, div(length(t._nodes), 2))
    rec_descendants(n, r)
    return r
end

function topo_depth(t::Tree, n::NodeID; state = 0)
    if t[n].parent == 1
        state
    else
        topo_depth(t, t[n].parent; state=state+1)
    end
end

function mrca(t::Tree, nodes::A) where A <: AbstractSet{NodeID}
    ancestors = ascendance(t, first(nodes))
    ranks = Dict(j => i for (i,j) in enumerate(ancestors))
    checked = Set(ancestors)
    oldest = 1
    for species in nodes
        while !(species ∈ checked)
            push!(checked, species)
            species = parent(t, species)
        end
        oldest = max(oldest, get(ranks, species, 0))
    end
    ancestors[oldest]
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
    function fmtTree(i::NodeID)::String
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
