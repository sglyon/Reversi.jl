# ---------- #
# State type #
# ---------- #

struct State
    board::Board
    player::Int
    round::Int
end
State() = State(Board(0, 0), 1, 0)

function Base.show(io::IO, mime::MIME"text/plain", s::State)
    if s.player == 1 || s.player == 2
        msg = "It is Player $(s.player)'s ($(MARKERS[s.player])) turn"
    else
        msg = "It is player $(s.player)'s turn"
    end

    println(io, msg, " on round $(s.round)")
    println(io, "The score is $(score(s)) and the board looks like:\n")
    show(io, mime, s.board)
end
Base.show(io::IO, s::State) = show(io, MIME"text/plain"(), s)

# --------------------------- #
# bitboard api for State type #
# --------------------------- #

function legal_actions_bits(s::State)
    if s.player == 1
        return legal_actions_bits(s.board.p1_placed, s.board.p2_placed)
    else
        return legal_actions_bits(s.board.p2_placed, s.board.p1_placed)
    end
end

score(s::State) = score(s.board.p1_placed), score(s.board.p2_placed)
legal_actions(s::State) = bits_to_tuples(legal_actions_bits(s))
function game_over(s::State)
    if s.round  < 4
        return false, 0, 0
    end
    game_over(s.board.p1_placed, s.board.p2_placed)
end

function do_action(s::State, action::UInt64)::State
    p1 = s.board.p1_placed
    p2 = s.board.p2_placed
    if s.player == 1
        new_p1, new_p2 = next_state_bits(action, p1, p2)
        new_player = 2
    else
        new_p2, new_p1 = next_state_bits(action, p2, p1)
        new_player = 1
    end
    State(Board(new_p1, new_p2), new_player, s.round+1)
end

do_action(s::State, a::Tuple{Int,Int}) = do_action(s, encode(a))
do_pass(s::State) = State(s.board, (s.player == 1) + 1, s.round)

opponent(i::Integer) = (i == 1) + 1
opponent(s::State) = opponent(state.player)
