abstract type Player end

select_action(p::Player, s::State) = select_action(p, s, legal_actions(s))
select_action(p::Player, s::State, g::Base.Generator) = select_action(p, s, collect(g))
select_action(p::Player, s::State, a::UInt64) = select_action(p, s, decode(a))

# ------------ #
# RandomPlayer #
# ------------ #

struct RandomPlayer <: Player end
select_action(p::RandomPlayer, s::State) = rand(legal_actions(s))

# ------- #
# Minimax #
# ------- #

struct Minimax{Teval} <: Player
    evaluator::Teval
    depth::Int
end

function minimax(p::Minimax, s::State, depth::Int)
    if depth == 0 || game_over(s)[1]
        val = p.evaluator(s)
        return val, (0, 0)
    end

    value(a_state::State) = -minimax(p, a_state, depth-1)[1]

    actions = legal_actions(s)

    if length(actions) == 0  # this guy can't go. Let him pass
        return value(do_pass(s)), (0, 0)
    end

    return maximum((value(do_action(s, a)), a) for a in actions)
end

select_action(p::Minimax, s::State) = minimax(p, s, p.depth)[2]

# ------------------ #
# Stochastic Minimax #
# ------------------ #

struct StochasticMinimax{Teval} <: Player
    evaluator::Teval
    depth::Int
end

function minimax(p::StochasticMinimax, s::State, depth::Int)::Tuple{Float64,Tuple{Int,Int}}
    if depth == 0 || game_over(s)[1]
        val = p.evaluator(s)
        return val, (0, 0)
    end

    actions = legal_actions(s)

    if length(actions) == 0  # this guy can't go. Let him pass
        return -minimax(p, do_pass(s), depth-1)[1], (0 ,0)
    end

    values = [-minimax(p, do_action(s, a), depth-1)[1] for a in actions]

    probs = values + abs(minimum(values)) + 1  # shift up so they all > 0
    probs = cumsum(probs ./ sum(probs))        # turn into cdf
    index = searchsortedfirst(probs, rand())   # sample from the cdf

    return values[index], actions[index]
end

select_action(p::StochasticMinimax, s::State) = minimax(p, s, p.depth)[2]
