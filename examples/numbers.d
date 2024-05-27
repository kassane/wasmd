import arsd.simpledisplay;

int[16] board;
bool victory;

enum TILE_SIZE = 64;

bool won() {
	if(board[$-1])
		return false;
	foreach(idx, item; board[0 .. $-1])
		if(item != idx + 1)
			return false;
	return true;
}

void init() {
	import std.random;

	int[16] indexes;
	foreach(idx, ref i; indexes)
		i = cast(int) idx;

	int[] remaining = indexes;

	int inversions = 0;
	bool parityOdd;

	int one, two;

	foreach(i; 0 .. 16) {
		auto r = uniform(0, remaining.length);
		auto n = remaining[r];
		board[i] = n;
		remaining[r] = remaining[$-1];
		remaining = remaining[0 .. $-1];

		if(n == 1)
			one = i;
		if(n == 2)
			two = i;

		if(n == 0) {
			parityOdd = (i / 4) % 2 == 0;
		} else {
			foreach(thing; remaining)
				if(thing && n > thing)
					inversions++;
		}
	}

	auto solvable = (inversions % 2) == parityOdd;

	if(!solvable) {
		// by swapping the 1 and the 2, we ought to toggle the parity just right
		// since 1 necessarily has 0 and 2 necessarily has 0 or 1...
		board[one] = 2;
		board[two] = 1;
	}
}

immutable string[16] strs = [
	" ",
	"1", "2", "3", "4",
	"5", "6", "7", "8",
	"9", "10", "11", "12",
	"13", "14", "15",
];

int selected;

void drawBoard(SimpleWindow window) {
	auto painter = window.draw();

	int x, y;

	foreach(idx, item; board) {
		painter.fillColor = idx == selected ? Color.yellow : victory ? Color.green : Color.white;
		painter.outlineColor = Color.black;

		painter.drawRectangle(Point(x, y), Size(TILE_SIZE, TILE_SIZE));
		painter.drawText(Point(x, y) + (TILE_SIZE / 2 - 4), strs[item]);
		x += TILE_SIZE;
		if(x == TILE_SIZE * 4) {
			y += TILE_SIZE;
			x = 0;
		}
	}
}

void slide() {
	int zero;
	foreach(idx, item; board)
		if(item == 0) { zero = cast(int) idx; break; }
	if(zero == selected)
		return;

	int sx = selected % 4;
	int sy = selected / 4;
	int zx = zero % 4;
	int zy = zero / 4;

	if(sx == zx) {
		while(zy != sy) {
			int next = (zy < sy) ? zy + 1 : zy - 1;
			int nidx = next * 4 + zx;
			board[zero] = board[nidx];
			board[nidx] = 0;
			zy = next;
			zero = nidx;
		}
	} else if(sy == zy) {
		while(zx != sx) {
			int next = (zx < sx) ? zx + 1 : zx - 1;
			int nidx = zy * 4 + next;
			board[zero] = board[nidx];
			board[nidx] = 0;
			zx = next;
			zero = nidx;
		}
	} else {
		// invalid move
	}

	if(won) {
		victory = true;
	}
}

void main() {
	init;
	auto window = new SimpleWindow(4 * TILE_SIZE, 4 * TILE_SIZE, "Number sliding puzzle");
	window.drawBoard();
	window.eventLoop(0,
		(KeyEvent ev) {
			if(!ev.pressed) return;
			switch(ev.key) {
				case Key.Left:
					selected--;
					if(selected < 0)
						selected = 15;
				break;
				case Key.Right:
					selected++;
					if(selected == 16)
						selected = 0;
				break;
				case Key.Up:
					selected -= 4;
					if(selected < 0)
						selected += 16;
				break;
				case Key.Down:
					selected += 4;
					if(selected >= 16)
						selected -= 16;
				break;
				case Key.Space:
					slide();
				break;
				default:
			}

			window.drawBoard();
		},
		(MouseEvent ev) {
			if(ev.type != MouseEventType.buttonPressed)
				return;

			auto x = ev.x / TILE_SIZE;
			auto y = ev.y / TILE_SIZE;

			selected = y * 4 + x;
			slide();

			window.drawBoard();
		});
}

