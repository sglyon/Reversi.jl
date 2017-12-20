mutable struct EdaxPlayer <: Player
    proc::Base.Process
    # TODO options

    function EdaxPlayer()
        c = Cmd(`./mEdax -n 1 -ponder off`, dir="/Users/sglyon/Downloads/edax/4.3/bin")
        proc = open(c, "w+")
        if !process_running(proc)
            error("error starting edax process")
        end
        read(proc, 1)
        read(proc.out, nb_available(proc.out))
        out = new(proc)
        finalizer(out) do x
            close(x.proc)
        end
        out
    end
end


function edax_board(s::State)
    b = s.board
    junk = fill('-', 8, 8)
    for (r, c) in bits_to_tuples(b.p1_placed)
        junk[c, r] = 'X'
    end
    for (r, c) in bits_to_tuples(b.p2_placed)
        junk[c, r] = 'O'
    end
    player = s.player == 1 ? " X" : " O"
    string(join(junk, ""), player)
end


function Base.write(e::EdaxPlayer, s::String)
    write(e.proc.in, s)
    out = read(e.proc.out, 1)
    append!(out, read(e.proc.out, nb_available(e.proc.out)))
    String(out)
end

set_board!(e::EdaxPlayer, s::State) = write(e, "setboard $(edax_board(s))\n")

function _get_edax_board(e::EdaxPlayer)
    write(e.proc.in, "\n")
    msg = readuntil(e.proc.out, "\n>")
    parse_edax_board(msg)
end

function parse_edax_board(msg::String)
    lines = split(msg, "\n")

    board_start = findfirst(line -> startswith(line, "  A"), lines)
    board = lines[board_start:board_start+9]

    markers_in_row = 3:2:17

    # extract tile positions
    p1_placed = UInt64(0)
    p2_placed = UInt64(0)
    for row in 1:8
        data = board[row+1]
        markers = data[markers_in_row]
        for col in 1:8
            if markers[col] == '*'
                p1_placed += encode(row, col)
            end
            if markers[col] == 'O'
                p2_placed += encode(row, col)
            end
        end
    end

    # extract turn
    turn = board[6][24] == 'B' ? 1 : 2

    # assume round is
    round = score(p1_placed) + score(p2_placed) + 1

    State(Board(p1_placed, p2_placed), turn, round)
end

function select_action(e::EdaxPlayer, s::State)
    if s.round < 4
        return rand(legal_actions(s))
    end
    set_board!(e, s)
    msg = write(e, "go\n")
    my_match = match(r"Edax plays (\w)(\d)", msg)
    row = parse(Int, my_match[2])
    col = Int(my_match[1][1]) - 64
    (row, col)
end
