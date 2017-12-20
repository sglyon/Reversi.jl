# ---------------------------- #
# bitboard stuff on primitives #
# ---------------------------- #

encode(r::Integer, c::Integer) = UInt64(1) << (8*(r-1) + (c-1))
encode(rc::Tuple{Integer,Integer}) = encode(rc[1], rc[2])
const CENTERS_BITS = sum(encode(i) for i in [(4, 4), (5, 5), (5, 4), (4, 5)])

function _one_directon_right_shift(g::UInt64, p::UInt64, n::Integer)
    g |= p & (g >> (n * 1))
    p &= (p >> (n * 1))
    g |= p & (g >> (n * 2))
    p &= (p >> (n * 2))
    g |= p & (g >> (n * 4))
    g
end

function _one_directon_left_shift(g::UInt64, p::UInt64, n::Integer)
    g |= p & (g << (n * 1))
    p &= (p << (n * 1))
    g |= p & (g << (n * 2))
    p &= (p << (n * 2))
    g |= p & (g << (n * 4))
    g
end

function _get_g_directions(p1::UInt64, p2::UInt64)
    mask_a = 0xfefefefefefefefe
    mask_h = 0x7f7f7f7f7f7f7f7f

    gN = _one_directon_right_shift(p1, p2, 8)
    gS = _one_directon_left_shift(p1, p2, 8)
    gE = _one_directon_left_shift(p1, p2 & mask_a, 1)
    gW = _one_directon_right_shift(p1, p2 & mask_h, 1)
    gNE = _one_directon_right_shift(p1, p2 & mask_a, 7)
    gNW = _one_directon_right_shift(p1, p2 & mask_h, 9)
    gSE = _one_directon_left_shift(p1, p2 & mask_a, 9)
    gSW = _one_directon_left_shift(p1, p2 & mask_h, 7)

    return gN, gS, gE, gW, gNE, gNW, gSE, gSW
end

function legal_actions_bits(mover::UInt64, opp::UInt64)
    occupied = mover | opp
    if (CENTERS_BITS & occupied) != CENTERS_BITS
        return CENTERS_BITS - occupied
    end

    mask_a = 0xfefefefefefefefe
    mask_h = 0x7f7f7f7f7f7f7f7f
    empty = 0xffffffffffffffff ⊻ occupied

    gN, gS, gE, gW, gNE, gNW, gSE, gSW = _get_g_directions(mover, opp)

    legal = UInt64(0)
    legal |= ((gN & ~mover) >> 8) & empty
    legal |= ((gS & ~mover) << 8) & empty
    legal |= ((gE & ~mover & mask_h) << 1) & empty
    legal |= ((gW & ~mover & mask_a) >> 1) & empty
    legal |= ((gNE & ~mover & mask_h) >> 7) & empty
    legal |= ((gNW & ~mover & mask_a) >> 9) & empty
    legal |= ((gSE & ~mover & mask_h) << 9) & empty
    legal |= ((gSW & ~mover & mask_a) << 7) & empty
    legal
end

function next_state_bits(action::UInt64, mover::UInt64, opponent::UInt64)
    gN, gS, gE, gW, gNE, gNW, gSE, gSW = _get_g_directions(
        action, opponent
    )

    mask_a = 0xfefefefefefefefe
    mask_h = 0x7f7f7f7f7f7f7f7f
    mover += action

    flips = UInt64(0)
    ((gN >> 8) & mover > 0)           && (flips |= gN)
    ((gS << 8) & mover > 0)           && (flips |= gS)
    ((gE << 1) & mask_a & mover > 0)  && (flips |= gE)
    ((gW >> 1) & mask_h & mover > 0)  && (flips |= gW)
    ((gNE >> 7) & mask_a & mover > 0) && (flips |= gNE)
    ((gNW >> 9) & mask_h & mover > 0) && (flips |= gNW)
    ((gSE << 9) & mask_a & mover > 0) && (flips |= gSE)
    ((gSW << 7) & mask_h & mover > 0) && (flips |= gSW)

    new_mover = mover | flips
    new_opponent = opponent & (~flips)

    new_mover, new_opponent
end

score(x::UInt64) = count_ones(x)

function bits_to_tuples(x::UInt64)
    out = Array{Tuple{Int,Int}}(uninitialized, count_ones(x))
    i = 0
    v = UInt64(1)  # equal to encode(1, 1)
    for r in 1:8
        for c in 1:8
            if v & x > 0
                out[i += 1] = (r, c)
            end
            v <<= 1  # now equal to encode(r, c+1) if (c <= 7)
                     #           or encode(r+1, 1) if (c == 8) and (r < 8)
        end
    end
    out
end

legal_actions(p1::UInt64, p2::UInt64) = bits_to_tuples(legal_actions_bits(p1, p2))

function game_over(p1::UInt64, p2::UInt64)::Tuple{Bool,Int,Int}
    if p1 == 0
        return true, 0, score(p2)
    end

    if p2 == 0
        return true, score(p1), 0
    end

    occupied = p1 | p2
    if occupied == (UInt64(1) << (64)) - 1
        return true, score(p1), score(p2)
    end

    if isempty(legal_actions(p1, p2)) && isempty(legal_actions(p2, p1))
        return true, score(p1), score(p2)
    end

    false, 0, 0
end


# ---------- #
# Board type #
# ---------- #

struct Board
    p1_placed::UInt64
    p2_placed::UInt64
end

function Base.show(io::IO, ::MIME"text/plain", b::Board)
    # corners
    top_left = "\u250C"
    top_right = "\u2510"
    bottom_left = "\u2514"
    bottom_right = "\u2518"

    # lines
    hori = "\u2500"
    vert = "\u2502"

    # line + center piece
    hori_down = "\u252C"
    hori_up = "\u2534"

    print(io, " ", join(map(i->string("  ", i, " "), 1:8)), "\n")
    print(io, " ", top_left, hori, repeat(string(hori^2, hori_down, hori), 7), hori^2, top_right)

    for r in UInt64(1):8
        println(io)
        print(io, r)
        print(io, vert)
        for c in UInt64(1):8
            v = encode(r, c)
            if v & b.p1_placed > 0
                print(io, MARKERS[1])
            elseif v & b.p2_placed > 0
                print(io, MARKERS[2])
            else
                print(io, MARKERS[0])
            end
            print(io, vert)
        end
    end

    println(io, "\n ", bottom_left, hori, repeat(string(hori^2, hori_up, hori), 7), hori^2, bottom_right)
end
Base.show(io::IO, b::Board) = show(io, MIME"text/plain"(), b)
