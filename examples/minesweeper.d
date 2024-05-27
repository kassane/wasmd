// next up: tetris!
// clock started: 19:50
// basically functional: 20:45, thanks to wikipedia btw

import arsd.simpledisplay;

/*
	Any click on a clear spot clears all clear spots up to the next number

	should have a timer
*/

enum GameSquare {
	mine = 0,
	clear,
	m1,
	m2,
	m3,
	m4,
	m5,
	m6,
	m7,
	m8
}

enum UserSquare {
	unknown,
	revealed,
	flagged,
	questioned
}

GameSquare[] board;
UserSquare[] userState;
int boardWidth;
int boardHeight;

void floodFill(T)(
	T[] what, int width, int height, // the canvas to inspect
	T target, T replacement, // fill params
	int x, int y, bool delegate(int x, int y) additionalCheck) // the node
{
	T node = what[y * width + x];

	if(target == replacement) return;

	if(node != target) return;

	if(!additionalCheck(x, y))
		return;

	what[y * width + x] = replacement;

	if(x)
		floodFill(what, width, height, target, replacement,
			x - 1, y, additionalCheck);

	if(x != width - 1)
		floodFill(what, width, height, target, replacement,
			x + 1, y, additionalCheck);

	if(y)
		floodFill(what, width, height, target, replacement,
			x, y - 1, additionalCheck);

	if(y != height - 1)
		floodFill(what, width, height, target, replacement,
			x, y + 1, additionalCheck);
}

bool isMine(int x, int y) {
	if(x < 0 || y < 0 || x >= boardWidth || y >= boardHeight)
		return false;
	return board[y * boardWidth + x] == GameSquare.mine;
}

enum GameState {
	inProgress,
	lose,
	win
}

GameState reveal(int x, int y) {
	if(board[y * boardWidth + x] == GameSquare.clear) {
		floodFill(userState, boardWidth, boardHeight,
			UserSquare.unknown, UserSquare.revealed,
			x, y,
			(x, y) {
				if(board[y * boardWidth + x] == GameSquare.clear)
					return true;
				else {
					userState[y * boardWidth + x] = UserSquare.revealed;
					return false;
				}
			});
	} else {
		userState[y * boardWidth + x] = UserSquare.revealed;
		if(isMine(x, y))
			return GameState.lose;
	}

	foreach(state; userState) {
		if(state == UserSquare.unknown || state == UserSquare.questioned)
			return GameState.inProgress;
	}

	return GameState.win;
}

void initializeBoard(int width, int height, int numberOfMines) {
	boardWidth = width;
	boardHeight = height;
	board.length = width * height;

	userState.length = width * height;
	userState[] = UserSquare.unknown; 

	import std.random;//, std.range;

	board[] = GameSquare.clear;

	//foreach(minePosition; randomSample(iota(0, board.length), numberOfMines))
		//board[minePosition] = GameSquare.mine;

	foreach(i; 0 .. numberOfMines) {
		// horrible hack, the above code is much better
		// but randomSample not on webassembly yet :(
		try_again:
		auto spot = uniform(0, board.length);
		if(board[spot] != GameSquare.clear)
			goto try_again;
		board[spot] = GameSquare.mine;
	}

	int x;
	int y;
	foreach(idx, ref square; board) {
		if(square == GameSquare.clear) {
			int danger = 0;
			danger += isMine(x-1, y-1)?1:0;
			danger += isMine(x-1, y)?1:0;
			danger += isMine(x-1, y+1)?1:0;
			danger += isMine(x, y-1)?1:0;
			danger += isMine(x, y+1)?1:0;
			danger += isMine(x+1, y-1)?1:0;
			danger += isMine(x+1, y)?1:0;
			danger += isMine(x+1, y+1)?1:0;

			square = cast(GameSquare) (danger + 1);
		}

		x++;
		if(x == width) {
			x = 0;
			y++;
		}
	}
}

void redraw(SimpleWindow window) {
	auto painter = window.draw();

	painter.clear();

	final switch(gameState) with(GameState) {
		case inProgress:
			break;
		case win:
			painter.fillColor = Color.green;
			painter.drawRectangle(Point(0, 0), window.width, window.height);
			return;
		case lose:
			painter.fillColor = Color.red;
			painter.drawRectangle(Point(0, 0), window.width, window.height);
			return;
	}

	int x = 0;
	int y = 0;

	foreach(idx, square; board) {
		auto state = userState[idx];

		final switch(state) with(UserSquare) {
			case unknown:
				painter.outlineColor = Color.black;
				painter.fillColor = Color(128,128,128);

				painter.drawRectangle(
					Point(x * 20, y * 20),
					20, 20
				);
			break;
			case revealed:
				if(square == GameSquare.clear) {
					painter.outlineColor = Color.white;
					painter.fillColor = Color.white;

					painter.drawRectangle(
						Point(x * 20, y * 20),
						20, 20
					);
				} else {
					painter.outlineColor = Color.black;
					painter.fillColor = Color.white;

					char[2] str;
					str[0] = cast(char) (cast(int) square - cast(int) GameSquare.m1 + 1 + '0');
					str[1] = 0;

					painter.drawText(
						Point(x * 20, y * 20),
						str[0 .. 1],
						Point(x * 20 + 20, y * 20 + 20),
						TextAlignment.Center | TextAlignment.VerticalCenter);
				}
			break;
			case flagged:
				painter.outlineColor = Color.black;
				painter.fillColor = Color.red;
				painter.drawRectangle(
					Point(x * 20, y * 20),
					20, 20
				);
			break;
			case questioned:
				painter.outlineColor = Color.black;
				painter.fillColor = Color.yellow;
				painter.drawRectangle(
					Point(x * 20, y * 20),
					20, 20
				);
			break;
		}

		x++;
		if(x == boardWidth) {
			x = 0;
			y++;
		}
	}

}

GameState gameState;

void main() {
	auto window = new SimpleWindow(200, 200);

	initializeBoard(10, 10, 10);

	window.redraw();
	window.eventLoop(0,
		delegate (MouseEvent me) {
			if(me.type != MouseEventType.buttonPressed)
				return;
			auto x = me.x / 20;
			auto y = me.y / 20;
			if(x >= 0 && x < boardWidth && y >= 0 && y < boardHeight) {
				if(me.button == MouseButton.left) {
					gameState = reveal(x, y);
				} else {
					userState[y*boardWidth+x] = UserSquare.flagged;
				}
				window.redraw();
			}
		}
	);
}

