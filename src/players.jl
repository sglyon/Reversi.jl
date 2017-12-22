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

# ------- #
# Scorers #
# ------- #

struct DidIWin end

function (d::DidIWin)(s::State)
    scores = score(s)
    scores[1] == scores[2] && return 0.0
    ifelse(scores[s.player] > scores[(s.player == 1) + 1], 1.0, -1.0)
end

struct MarginOfVictory end

function (d::MarginOfVictory)(s::State)
    scores = score(s)
    scores[s.player] - scores[(s.player == 1) + 1]
end

# ---------- #
# Evaluators #
# ---------- #
udpate_evaluator!(evaluator, action::Tuple{Int,Int}) = nothing

# ------------------- #
# MonteCarloEvaluator #
# ------------------- #

struct MonteCarloEvaluator{TScore,Tp1<:Player, Tp2<:Player}
    nsim::Int
    scorer::TScore  # computes score for a state. Should return score for state.player
    p1::Tp1
    p2::Tp2
end

function MonteCarloEvaluator(nsim::Int, scorer=DidIWin())
    MonteCarloEvaluator(nsim, scorer, AlphaBetaPruning(WeightedSum(false), 1), RandomPlayer())
end

function (mc::MonteCarloEvaluator)(s::State)
    tot = 0.0
    for sim in 1:mc.nsim
        final_s = Reversi.play_game(mc.p1, mc.p2, s, disp=false)
        score = mc.scorer(final_s)
        tot += final_s.player == s.player ? score : -score
    end
    return tot / mc.nsim
end

# --------------------- #
# WeightedSum Evaluator #
# --------------------- #

struct WeightedSum
    weights::Matrix{Float64}
    update::Bool
end

function WeightedSum()
    weights = Float64[
        120 -20  20   5   5  20 -20 120
        -20 -40  -5  -5  -5  -5 -40 -20
         20  -5  15   3   3  15  -5  20
          5  -5   3   3   3   3  -5   5
          5  -5   3   3   3   3  -5   5
         20  -5  15   3   3  15  -5  20
        -20 -40  -5  -5  -5  -5 -40 -20
        120 -20  20   5   5  20 -20 120
    ]
    WeightedSum(weights)
end

WeightedSum(update::Bool) = WeightedSum(WeightedSum().weights, false)
WeightedSum(weights::Matrix) = WeightedSum(weights, true)

function (ws::WeightedSum)(s::State)
    p1_score = 0.0
    for (r, c) in bits_to_tuples(s.board.p1_placed)
        p1_score += ws.weights[r, c]
    end

    p2_score = 0.0
    for (r, c) in bits_to_tuples(s.board.p2_placed)
        p2_score += ws.weights[r, c]
    end

    diff = p1_score - p2_score

    s.player == 1 ? diff : -diff
end

function udpate_evaluator!(ws::WeightedSum, action::Tuple{Int,Int})
    (!ws.update) && return
    # if we got a corner, we should no longer be afraid of the places next to it
    if action == (1, 1)
        println("Updating for corner")
        for position in [(1, 2), (2, 1), (2, 2)]
            ws.weights[position...] = ws.weights[1, 1]
        end
    end
    if action == (8, 8)
        println("Updating for corner")
        for position in [(7, 8), (8, 7), (7, 7)]
            ws.weights[position...] = ws.weights[8, 8]
        end
    end
    if action == (1, 8)
        println("Updating for corner")
        for position in [(1, 7), (2, 8), (2, 7)]
            ws.weights[position...] = ws.weights[1, 8]
        end
    end
    if action == (8, 1)
        println("Updating for corner")
        for position in [(7, 1), (8, 2), (7, 2)]
            ws.weights[position...] = ws.weights[8, 1]
        end
    end

end

# ------------------ #
# Alpha beta pruning #
# ------------------ #

mutable struct AlphaBetaPruning{Teval} <: Player
    evaluator::Teval
    depth::Int
    searched::Int
end

AlphaBetaPruning(evaluator, depth::Int) = AlphaBetaPruning(evaluator, depth, 0)

function alphabeta(p::AlphaBetaPruning, s::State, depth::Int, alpha, beta)
    if depth == 0 || game_over(s)[1]
        val = p.evaluator(s)
        return val, (0, 0)
    end

    actions = legal_actions(s)

    if length(actions) == 0  # this guy can't go. Let him pass
        return -alphabeta(p, do_pass(s), depth-1, -beta, -alpha)[1], (0, 0)
    end

    best_action = actions[1]
    for action in actions
        p.searched += 1
        if alpha >= beta
            break
        end
        val = -alphabeta(p, do_action(s, action), depth-1, -beta, -alpha)[1]
        if val > alpha
            alpha = val
            best_action = action
        end
    end
    return alpha, best_action
end

function select_action(p::AlphaBetaPruning, s::State)
    # start_time = time()
    p.searched = 0

    if count_ones(legal_actions_bits(s)) == 1
        return legal_actions(s)[1]
    end

    best_action = alphabeta(p, s, p.depth, -Inf, Inf)[2]
    udpate_evaluator!(p.evaluator, best_action)
    # end_time = time()
    # board = (s.board.p1_placed, s.board.p2_placed)
    # println("From board $(board) searched $(p.searched) actions in $(end_time-start_time) seconds")
    best_action
end
