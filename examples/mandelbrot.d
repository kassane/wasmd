/// Mandelbrot set fractal viewer.
///
/// Arrow keys to pan, [ / ] to zoom in/out.
/// Renders the Mandelbrot set using iterated escape-time algorithm
/// with smooth coloring via HSL.
/// Demonstrates: heavy floating-point arithmetic, pixel-level canvas rendering,
///               keyboard-driven viewport navigation, HSL color generation,
///               nested loops over large grids.
import arsd.simpledisplay;
import arsd.color;

enum Width = 400;
enum Height = 400;
enum MaxIter = 80;

// Viewport in complex plane
__gshared double centerX = -0.5;
__gshared double centerY = 0.0;
__gshared double zoom = 3.0; // width of viewport in complex-plane units
__gshared bool needsRedraw = true;

Color iterToColor(int iter)
{
    if (iter >= MaxIter)
        return Color.black;

    // Map iteration count to HSL for smooth coloring
    double hue = (cast(double) iter / MaxIter) * 360.0;
    double sat = 0.9;
    double light = 0.5;
    return Color.fromHsl(hue, sat, light);
}

void render(SimpleWindow window)
{
    auto painter = window.draw();

    double pixelSize = zoom / Width;
    double x0 = centerX - zoom / 2.0;
    double y0 = centerY - zoom / 2.0;

    foreach (py; 0 .. Height)
    {
        double ci = y0 + py * pixelSize;
        foreach (px; 0 .. Width)
        {
            double cr = x0 + px * pixelSize;

            // z = z^2 + c, starting from z = 0
            double zr = 0.0;
            double zi = 0.0;
            int iter = 0;
            while (iter < MaxIter)
            {
                double zr2 = zr * zr;
                double zi2 = zi * zi;
                if (zr2 + zi2 > 4.0)
                    break;
                zi = 2.0 * zr * zi + ci;
                zr = zr2 - zi2 + cr;
                iter++;
            }

            Color c = iterToColor(iter);
            painter.fillColor = c;
            painter.outlineColor = c;
            // Draw 1x1 pixel as a tiny rectangle
            painter.drawRectangle(Point(px, py), 1, 1);
        }
    }

    needsRedraw = false;
}

void main()
{
    auto window = new SimpleWindow(Width, Height, "Mandelbrot");

    render(window);

    window.eventLoop(1000 / 10,
        delegate()
        {
            if (needsRedraw)
                render(window);
        },
        delegate(KeyEvent ev)
        {
            if (!ev.pressed)
                return;

            double panStep = zoom * 0.15;

            switch (ev.key)
            {
            case Key.Left:
                centerX -= panStep;
                needsRedraw = true;
                break;
            case Key.Right:
                centerX += panStep;
                needsRedraw = true;
                break;
            case Key.Up:
                centerY -= panStep;
                needsRedraw = true;
                break;
            case Key.Down:
                centerY += panStep;
                needsRedraw = true;
                break;
            case Key.LeftBracket: // zoom in
                zoom *= 0.6;
                needsRedraw = true;
                break;
            case Key.RightBracket: // zoom out
                zoom /= 0.6;
                needsRedraw = true;
                break;
            default:
            }
        }
    );
}
