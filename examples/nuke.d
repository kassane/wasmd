import arsd.simpledisplay;

void main() {
	auto window = new SimpleWindow(512, 512);

	float h = 3;
	float s = 0.5;
	float l = 0.5;

	window.eventLoop(50, delegate (KeyEvent ev) {
		version(WebAssembly) {} else {
			if(ev.key == Key.Space && ev.pressed) {
				import arsd.png;
				writePng("nuked.png", window.takeScreenshot());
			}
		}
	}, () {
		auto painter = window.draw();

		auto dim = 512;
		while(dim > 5) {

			h += 3;
			s += 0.03;
			l += 0.07;
			if(h >= 360) h -= 360;
			if(s >= 1.0) s -= 1.0;
			if(l >= 1.0) l -= 1.0;

			painter.fillColor = Color.fromHsl(h, s, l);
			painter.drawCircle(Point(dim, dim), dim);
			dim -= 5;
		}
	});
}

