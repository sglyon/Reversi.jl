__precompile__(true)
module Reversi

export
    # types
    Board, State, Player, RandomPlayer, Minimax, StochasticMinimax,

    # board
    encode, legal_actions_bits, next_state_bits, score, bits_to_tuples,
    legal_actions, game_over,

    # state
    do_action, do_pass, opponent,

    # player
    select_action

const MARKERS = Dict(0 => "   ", 2 => " \u25cf ", 1 => " \u25cb ")

include("board.jl")
include("state.jl")
include("players.jl")
include("gameplay.jl")

include("edax.jl")
# package code goes here

end # module
