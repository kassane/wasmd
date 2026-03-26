/// Classic Snake game.
///
/// Arrow keys to steer. The snake grows when it eats food.
/// Game over on self-collision or wall collision.
/// Demonstrates: dynamic arrays as snake body, random food placement,
///               keyboard input, game state machine, wrap-around logic,
///               associative-array-like collision via linear scan.
import arsd.simpledisplay;
import std.random;

enum CellSize = 12;
enum GridW = 32;
enum GridH = 32;
enum CanvasW = GridW * CellSize;
enum CanvasH = GridH * CellSize;

enum Direction
{
    up,
    down,
    left,
    right,
}

struct Coord
{
    int x, y;
}

// --- game state (module-level for delegate capture) ---
__gshared Coord[] body_;
__gshared Direction dir = Direction.right;
__gshared Direction nextDir = Direction.right;
__gshared Coord food;
__gshared bool gameOver = false;
__gshared int score = 0;
__gshared int tickCounter = 0;
__gshared int tickRate = 4; // frames per move

void placeFood()
{
    // Keep trying until we find an empty cell
    outer: while (true)
    {
        food = Coord(uniform(0, GridW), uniform(0, GridH));
        foreach (seg; body_)
            if (seg.x == food.x && seg.y == food.y)
                continue outer;
        break;
    }
}

bool collidesWithBody(int x, int y)
{
    foreach (seg; body_)
        if (seg.x == x && seg.y == y)
            return true;
    return false;
}

void tick()
{
    if (gameOver)
        return;

    dir = nextDir;

    // Compute new head position
    Coord head = body_[0];
    switch (dir)
    {
    case Direction.up:
        head.y--;
        break;
    case Direction.down:
        head.y++;
        break;
    case Direction.left:
        head.x--;
        break;
    case Direction.right:
        head.x++;
        break;
    default:
    }

    // Wall collision
    if (head.x < 0 || head.x >= GridW || head.y < 0 || head.y >= GridH)
    {
        gameOver = true;
        return;
    }

    // Self collision (skip tail if not growing)
    bool ate = (head.x == food.x && head.y == food.y);
    if (!ate)
    {
        // Check against body excluding the tail (which will be removed)
        foreach (i; 0 .. body_.length - 1)
            if (body_[i].x == head.x && body_[i].y == head.y)
            {
                gameOver = true;
                return;
            }
    }
    else
    {
        foreach (seg; body_)
            if (seg.x == head.x && seg.y == head.y)
            {
                gameOver = true;
                return;
            }
    }

    // Move: insert head, remove tail (unless eating)
    // Shift body right by 1
    body_ ~= Coord(0, 0); // grow by 1
    for (int i = cast(int) body_.length - 1; i > 0; i--)
        body_[i] = body_[i - 1];
    body_[0] = head;

    if (!ate)
    {
        // Remove tail
        body_ = body_[0 .. $ - 1];
    }
    else
    {
        score++;
        placeFood();
    }
}

void drawGame(SimpleWindow window)
{
    auto painter = window.draw();

    // Background
    painter.fillColor = Color(15, 15, 15);
    painter.outlineColor = Color(15, 15, 15);
    painter.drawRectangle(Point(0, 0), CanvasW, CanvasH);

    // Grid lines (subtle)
    painter.outlineColor = Color(30, 30, 30);
    painter.fillColor = Color(30, 30, 30);
    foreach (x; 0 .. GridW)
        foreach (y; 0 .. GridH)
            painter.drawRectangle(Point(x * CellSize, y * CellSize), CellSize, CellSize);

    // Food
    painter.fillColor = Color.red;
    painter.outlineColor = Color.red;
    painter.drawRectangle(Point(food.x * CellSize + 1, food.y * CellSize + 1), CellSize - 2, CellSize - 2);

    // Snake body
    foreach (i, seg; body_)
    {
        if (i == 0)
        {
            // Head - brighter
            painter.fillColor = Color(100, 255, 100);
            painter.outlineColor = Color(100, 255, 100);
        }
        else
        {
            painter.fillColor = Color.green;
            painter.outlineColor = Color.green;
        }
        painter.drawRectangle(Point(seg.x * CellSize + 1, seg.y * CellSize + 1), CellSize - 2, CellSize - 2);
    }

    // Score
    painter.outlineColor = Color.white;
    import std.stdio;

    // Game over overlay
    if (gameOver)
    {
        painter.fillColor = Color(80, 0, 0);
        painter.outlineColor = Color.white;
        painter.drawRectangle(Point(CanvasW / 4, CanvasH / 2 - 20), CanvasW / 2, 40);
        painter.drawText(Point(CanvasW / 4 + 10, CanvasH / 2 - 5), "GAME OVER");
    }
}

void main()
{
    // Initial snake: 4 segments in the middle, facing right
    int startX = GridW / 2;
    int startY = GridH / 2;
    foreach (i; 0 .. 4)
        body_ ~= Coord(startX - i, startY);

    placeFood();

    auto window = new SimpleWindow(CanvasW, CanvasH, "Snake");

    drawGame(window);

    window.eventLoop(1000 / 20,
        delegate()
        {
            tickCounter++;
            if (tickCounter >= tickRate)
            {
                tickCounter = 0;
                tick();
                drawGame(window);
            }
        },
        delegate(KeyEvent ev)
        {
            if (!ev.pressed)
                return;
            switch (ev.key)
            {
            case Key.Up:
                if (dir != Direction.down)
                    nextDir = Direction.up;
                break;
            case Key.Down:
                if (dir != Direction.up)
                    nextDir = Direction.down;
                break;
            case Key.Left:
                if (dir != Direction.right)
                    nextDir = Direction.left;
                break;
            case Key.Right:
                if (dir != Direction.left)
                    nextDir = Direction.right;
                break;
            default:
            }
        }
    );
}
