# Reversi.jl

[![Build Status](https://travis-ci.org/sglyon/Reversi.jl.svg?branch=master)](https://travis-ci.org/sglyon/Reversi.jl)

[![Coverage Status](https://coveralls.io/repos/sglyon/Reversi.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/sglyon/Reversi.jl?branch=master)

[![codecov.io](http://codecov.io/github/sglyon/Reversi.jl/coverage.svg?branch=master)](http://codecov.io/github/sglyon/Reversi.jl?branch=master)


Implements the game of [Reversi](https://en.wikipedia.org/wiki/Reversi) (also known as Othello) in Julia.

the standard 8x8 version of the game is implemented.

The board is represented efficiently using bitboards, which allows the use of
efficient bitwise operations for move generation and state updates.

The game mechanics are fully implemented, but the package needs to be more
fleshed out. See the [issue
tracker](https://github.com/sglyon/Reversi.jl/issues) for what is currently on
our radar for implementation.
