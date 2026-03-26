/// Breakout / brick-breaker game.
///
/// Left/Right arrows to move paddle. Space to launch ball.
/// Demonstrates: real-time physics (ball velocity, reflection),
///               collision detection (ball vs bricks, paddle, walls),
///               game state management, dynamic array of bricks,
///               class hierarchy, score tracking, HSL colored bricks.
import arsd.simpledisplay;
import arsd.color;

enum CanvasW = 480;
enum CanvasH = 400;

// Paddle
enum PaddleW = 60;
enum PaddleH = 10;
enum PaddleY = CanvasH - 30;

// Ball
enum BallRadius = 4;

// Bricks
enum BrickCols = 12;
enum BrickRows = 6;
enum BrickW = 36;
enum BrickH = 14;
enum BrickPadding = 2;
enum BrickOffsetX = (CanvasW - BrickCols * (BrickW + BrickPadding)) / 2;
enum BrickOffsetY = 40;

struct Brick
{
    int col, row;
    bool alive;
    Color color;

    int left() { return BrickOffsetX + col * (BrickW + BrickPadding); }
    int top() { return BrickOffsetY + row * (BrickH + BrickPadding); }
    int right() { return left() + BrickW; }
    int bottom() { return top() + BrickH; }
}

// --- game state ---
__gshared float paddleX = CanvasW / 2.0 - PaddleW / 2.0;
__gshared float ballX = CanvasW / 2.0;
__gshared float ballY = PaddleY - BallRadius - 1;
__gshared float ballDX = 2.5;
__gshared float ballDY = -2.5;
__gshared bool ballLaunched = false;
__gshared bool gameWon = false;
__gshared bool gameLost = false;
__gshared int score = 0;
__gshared int lives = 3;

__gshared bool movingLeft = false;
__gshared bool movingRight = false;

__gshared Brick[] bricks;

void initBricks()
{
    foreach (row; 0 .. BrickRows)
        foreach (col; 0 .. BrickCols)
        {
            float hue = (cast(float) row / BrickRows) * 300.0;
            Brick b;
            b.col = col;
            b.row = row;
            b.alive = true;
            b.color = Color.fromHsl(hue, 0.8, 0.5);
            bricks ~= b;
        }
}

void resetBall()
{
    ballX = paddleX + PaddleW / 2.0;
    ballY = PaddleY - BallRadius - 1;
    ballDX = 2.5;
    ballDY = -2.5;
    ballLaunched = false;
}

void updatePhysics()
{
    if (!ballLaunched || gameWon || gameLost)
        return;

    // Move paddle
    float paddleSpeed = 5.0;
    if (movingLeft && paddleX > 0)
        paddleX -= paddleSpeed;
    if (movingRight && paddleX + PaddleW < CanvasW)
        paddleX += paddleSpeed;

    // Move ball
    ballX += ballDX;
    ballY += ballDY;

    // Wall collisions
    if (ballX - BallRadius <= 0)
    {
        ballX = BallRadius;
        ballDX = -ballDX;
    }
    if (ballX + BallRadius >= CanvasW)
    {
        ballX = CanvasW - BallRadius;
        ballDX = -ballDX;
    }
    if (ballY - BallRadius <= 0)
    {
        ballY = BallRadius;
        ballDY = -ballDY;
    }

    // Ball falls below paddle
    if (ballY + BallRadius >= CanvasH)
    {
        lives--;
        if (lives <= 0)
            gameLost = true;
        else
            resetBall();
        return;
    }

    // Paddle collision
    if (ballDY > 0 &&
        ballY + BallRadius >= PaddleY &&
        ballY + BallRadius <= PaddleY + PaddleH &&
        ballX >= paddleX &&
        ballX <= paddleX + PaddleW)
    {
        ballDY = -ballDY;
        // Angle based on where ball hits paddle
        float hitPos = (ballX - paddleX) / PaddleW; // 0..1
        ballDX = (hitPos - 0.5) * 5.0;
        ballY = PaddleY - BallRadius - 1;
    }

    // Brick collisions
    int aliveCount = 0;
    foreach (ref b; bricks)
    {
        if (!b.alive)
            continue;
        aliveCount++;

        // Simple AABB check
        if (ballX + BallRadius >= b.left() &&
            ballX - BallRadius <= b.right() &&
            ballY + BallRadius >= b.top() &&
            ballY - BallRadius <= b.bottom())
        {
            b.alive = false;
            score += 10;
            aliveCount--;

            // Determine reflection axis
            float overlapLeft = (ballX + BallRadius) - b.left();
            float overlapRight = b.right() - (ballX - BallRadius);
            float overlapTop = (ballY + BallRadius) - b.top();
            float overlapBottom = b.bottom() - (ballY - BallRadius);

            float minOverlapX = overlapLeft < overlapRight ? overlapLeft : overlapRight;
            float minOverlapY = overlapTop < overlapBottom ? overlapTop : overlapBottom;

            if (minOverlapX < minOverlapY)
                ballDX = -ballDX;
            else
                ballDY = -ballDY;
            break; // one brick per frame
        }
    }

    if (aliveCount == 0)
        gameWon = true;
}

void drawGame(SimpleWindow window)
{
    auto painter = window.draw();

    // Background
    painter.fillColor = Color(10, 10, 30);
    painter.outlineColor = Color(10, 10, 30);
    painter.drawRectangle(Point(0, 0), CanvasW, CanvasH);

    // Bricks
    foreach (ref b; bricks)
    {
        if (!b.alive)
            continue;
        painter.fillColor = b.color;
        painter.outlineColor = Color.white;
        painter.drawRectangle(Point(b.left(), b.top()), BrickW, BrickH);
    }

    // Paddle
    painter.fillColor = Color(200, 200, 200);
    painter.outlineColor = Color.white;
    painter.drawRectangle(Point(cast(int) paddleX, PaddleY), PaddleW, PaddleH);

    // Ball
    painter.fillColor = Color.yellow;
    painter.outlineColor = Color.yellow;
    painter.drawCircle(Point(cast(int) ballX - BallRadius, cast(int) ballY - BallRadius), BallRadius * 2);

    // HUD: lives
    foreach (i; 0 .. lives)
    {
        painter.fillColor = Color.red;
        painter.outlineColor = Color.red;
        painter.drawCircle(Point(10 + i * 16, 5), 10);
    }

    // Overlays
    if (!ballLaunched && !gameLost && !gameWon)
    {
        painter.outlineColor = Color.white;
        painter.drawText(Point(CanvasW / 2 - 60, CanvasH / 2), "SPACE to launch");
    }
    if (gameWon)
    {
        painter.fillColor = Color(0, 80, 0);
        painter.outlineColor = Color.white;
        painter.drawRectangle(Point(CanvasW / 4, CanvasH / 2 - 20), CanvasW / 2, 40);
        painter.drawText(Point(CanvasW / 4 + 10, CanvasH / 2 - 5), "YOU WIN!");
    }
    if (gameLost)
    {
        painter.fillColor = Color(80, 0, 0);
        painter.outlineColor = Color.white;
        painter.drawRectangle(Point(CanvasW / 4, CanvasH / 2 - 20), CanvasW / 2, 40);
        painter.drawText(Point(CanvasW / 4 + 10, CanvasH / 2 - 5), "GAME OVER");
    }
}

void main()
{
    initBricks();

    auto window = new SimpleWindow(CanvasW, CanvasH, "Breakout");

    drawGame(window);

    window.eventLoop(1000 / 60,
        delegate()
        {
            if (!ballLaunched && !gameLost)
            {
                // Paddle follows even before launch
                float paddleSpeed = 5.0;
                if (movingLeft && paddleX > 0)
                    paddleX -= paddleSpeed;
                if (movingRight && paddleX + PaddleW < CanvasW)
                    paddleX += paddleSpeed;

                // Ball sits on paddle
                ballX = paddleX + PaddleW / 2.0;
                ballY = PaddleY - BallRadius - 1;
            }
            else
            {
                updatePhysics();
            }
            drawGame(window);
        },
        delegate(KeyEvent ev)
        {
            switch (ev.key)
            {
            case Key.Left:
                movingLeft = ev.pressed;
                break;
            case Key.Right:
                movingRight = ev.pressed;
                break;
            case Key.Space:
                if (ev.pressed && !ballLaunched && !gameLost && !gameWon)
                    ballLaunched = true;
                break;
            default:
            }
        }
    );
}
