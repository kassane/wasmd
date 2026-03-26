/// Conway's Game of Life - cellular automaton.
///
/// Click cells to toggle alive/dead. Press Space to start/stop.
/// Arrow Up/Down to adjust simulation speed.
/// Demonstrates: 2D array manipulation, mouse input, timer-driven simulation,
///               double-buffering state, canvas drawing.
import arsd.simpledisplay;

enum CellSize = 6;
enum GridW = 80;
enum GridH = 80;
enum CanvasW = GridW * CellSize;
enum CanvasH = GridH * CellSize;

int cellIndex(int x, int y)
{
    return ((y + GridH) % GridH) * GridW + ((x + GridW) % GridW);
}

__gshared int[] grid;
__gshared int[] next;
__gshared bool running = false;
__gshared int speed = 5; // 1-10, frames between steps
__gshared int frameCount = 0;

int countNeighbors(int cx, int cy)
{
    int n = 0;
    foreach (dy; -1 .. 2)
        foreach (dx; -1 .. 2)
        {
            if (dx == 0 && dy == 0)
                continue;
            n += grid[cellIndex(cx + dx, cy + dy)];
        }
    return n;
}

void step()
{
    foreach (y; 0 .. GridH)
        foreach (x; 0 .. GridW)
        {
            int n = countNeighbors(x, y);
            int alive = grid[y * GridW + x];
            // B3/S23 rules
            if (alive)
                next[y * GridW + x] = (n == 2 || n == 3) ? 1 : 0;
            else
                next[y * GridW + x] = (n == 3) ? 1 : 0;
        }

    // swap
    auto tmp = grid;
    grid = next;
    next = tmp;
}

void drawGrid(SimpleWindow window)
{
    auto painter = window.draw();
    foreach (y; 0 .. GridH)
        foreach (x; 0 .. GridW)
        {
            bool alive = grid[y * GridW + x] != 0;
            painter.fillColor = alive ? Color.green : Color(20, 20, 20);
            painter.outlineColor = Color(40, 40, 40);
            painter.drawRectangle(Point(x * CellSize, y * CellSize), CellSize, CellSize);
        }
}

/// Seed a glider at position (gx, gy) in grid coordinates.
void seedGlider(int gx, int gy)
{
    // Standard glider pattern:
    //  .X.
    //  ..X
    //  XXX
    int[2][5] cells = [
        [gx + 1, gy + 0],
        [gx + 2, gy + 1],
        [gx + 0, gy + 2],
        [gx + 1, gy + 2],
        [gx + 2, gy + 2],
    ];
    foreach (c; cells)
        grid[cellIndex(c[0], c[1])] = 1;
}

/// Seed an R-pentomino at (gx, gy).
void seedRPentomino(int gx, int gy)
{
    // .XX
    // XX.
    // .X.
    int[2][5] cells = [
        [gx + 1, gy + 0],
        [gx + 2, gy + 0],
        [gx + 0, gy + 1],
        [gx + 1, gy + 1],
        [gx + 1, gy + 2],
    ];
    foreach (c; cells)
        grid[cellIndex(c[0], c[1])] = 1;
}

void main()
{
    grid = new int[](GridW * GridH);
    next = new int[](GridW * GridH);

    // Seed some interesting patterns
    seedGlider(2, 2);
    seedGlider(10, 2);
    seedRPentomino(GridW / 2 - 1, GridH / 2 - 1);

    auto window = new SimpleWindow(CanvasW, CanvasH, "Game of Life");

    drawGrid(window);

    window.eventLoop(1000 / 30,
        delegate()
        {
            if (running)
            {
                frameCount++;
                if (frameCount >= (11 - speed))
                {
                    frameCount = 0;
                    step();
                    drawGrid(window);
                }
            }
        },
        delegate(KeyEvent ev)
        {
            if (!ev.pressed)
                return;
            switch (ev.key)
            {
            case Key.Space:
                running = !running;
                break;
            case Key.Up:
                if (speed < 10)
                    speed++;
                break;
            case Key.Down:
                if (speed > 1)
                    speed--;
                break;
            default:
            }
        },
        delegate(MouseEvent ev)
        {
            if (ev.type == MouseEventType.buttonPressed && ev.button == MouseButton.left)
            {
                int gx = ev.x / CellSize;
                int gy = ev.y / CellSize;
                if (gx >= 0 && gx < GridW && gy >= 0 && gy < GridH)
                {
                    grid[gy * GridW + gx] ^= 1;
                    drawGrid(window);
                }
            }
        }
    );
}
