"""
    trace_game(p1::Player, p2::Player, s::State=State(); disp::Bool=true)

Using players `p1` and `p2`, simulate the game starting from state `s`. If
`disp` is true, the board will be printed at the start of each turn. Returns a
`Vector{State}` that records the history of the game
"""
function trace_game(p1::Player, p2::Player, s::State=State(); disp::Bool=true)
    players = (p1, p2)
    history = State[]
    while !(game_over(s)[1])
        push!(history, s)
        disp && show(s)
        actions_bits = legal_actions_bits(s)
        if actions_bits == 0
            s = do_pass(s)
            continue
        end
        action = select_action(players[s.player], s)
        s = do_action(s, action)
    end
    score(s), history
end

"""
     play_game(p1::Player, p2::Player, s::State=State(); disp::Bool=false)

Using players `p1` and `p2`, simulate the game starting from state `s`. If
`disp` is true, the board will be printed at the start of each turn. Returns
the final state
"""
function play_game(p1::Player, p2::Player, s::State=State(); disp::Bool=false)
    players = (p1, p2)
    while !(game_over(s)[1])
        actions_bits = legal_actions_bits(s)
        if actions_bits == 0
            s = do_pass(s)
            continue
        end
        action = select_action(players[s.player], s)
        s = do_action(s, action)
    end
    s
end
