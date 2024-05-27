/+
	CoronaViruses just float around. If they touch a cell, they infect it and no longer exist.

	If they touch you, you take damage.

	If you shoot them, they die.

	If they touch each other, nothing happens, they just pass through unaffected.

	Cells will periodically undergo mitosis and split into two half-sized daughter cells
	once they reach a certain size. If they are infected, they burst into more coronaviruses
	at this point.

	If they touch you or each other, you bounce off each other.

	If you shoot them, they burst, similar to mitosis. If below a certain size, they die.

	If all the cells are destroyed, it is game over, the patient dies.

	If all the coronaviruses are destroyed, you win.


	Multiplayer is supposed to be cooperative... but if you hit each other, you exchange momentum... and if you shoot each other, you take damage.

	If you die, you lose.


	If rotation speed too high, you fly apart.

+/
import arsd.simpledisplay;

import std.math;
import std.random;

struct PolarCoord {
	float a = 0.0;
	float r = 0.0;
}

class GameObject {
	float x = 100.0;
	float y = 100.0;
	float a = 1.0;

	float dx = 0.4;
	float dy = 0.0;
	float da = 0.04;

	abstract immutable(PolarCoord)[] vertexes();
	abstract float radius();

	GameObject replacement() { return null; }

	void move() {
		x += dx;
		y += dy;
		a += da;

		if(x >= 512)
			x -= 512;
		if(y >= 512)
			y -= 512;
		if(x < 0)
			x += 512;
		if(y < 0)
			y += 512;
	}

	void draw(ScreenPainter* painter) {
		auto lines = vertexes();
		auto first = getPoint(lines[0]);
		auto previous = first;
		foreach(point; lines[1 .. $]) {
			auto next = getPoint(point);
			painter.drawLine(previous, next);
			previous = next;
		}

		painter.drawLine(previous, first);
	}

	final Point getPoint(PolarCoord coord) {
		return Point(
			cast(int) (x + radius * coord.r * cos(a + coord.a)),
			cast(int) (y + radius * coord.r * sin(a + coord.a)),
		);
	}

	float lifetime() { return float.infinity; }

	void getHitBy(GameObject) {}
}

class Ship : GameObject {
	int cooldown;
	override float radius() { return 16; }
	static immutable PolarCoord[] lines = [PolarCoord(0.0, 0), PolarCoord(PI - PI / 6, 1.0), PolarCoord(0, 1.0), PolarCoord(PI + PI / 6, 1.0)];
	override immutable(PolarCoord)[] vertexes() { return lines; }

	/*
		Color goes from green to orange to red
	*/
	int hp = 1200;

	override void draw(ScreenPainter* painter) {
		version(WebAssembly)
			painter.outlineColor = Color.white;
		else
			painter.outlineColor = Color.fromHsl(hp / 10, 1.0, 0.5);
		super.draw(painter);
	}

	override void getHitBy(GameObject o) {
		if(cast(Ship) o || cast(Cell) o) {
			// we bounce off ships and cells
			auto tdx = this.dx;
			auto tdy = this.dy;
			this.dx = o.dx;
			this.dy = o.dy;
			o.dx = tdx;
			o.dy = tdy;
		} else {
			// but take damage from everything else
			hp -= 400;
		}
	}
}

template roundObject(int segmentsCount, bool convex) {
	PolarCoord[] impl() pure {
		PolarCoord[] items;
		float a = 0;
		float step = PI * 2 / segmentsCount;
		foreach(i; 0 .. segmentsCount) {
			items ~= PolarCoord(a, (!convex || i%2) ? 1.0 : 0.5);
			a += step;
		}

		return items;
	}

	static immutable roundObject = impl();
}

class Cell : GameObject {
	this(float radius, float x, float y, float dx, float dy) {
		this.dx = dx;
		this.dy = dy;
		this.x = x;
		this.y = y;
		radius_ = radius; // want to go up to 24, then mitosis!
		timeToBurst = 120;
		count++;
	}
	static int count;
	float radius_;
	int timeToBurst;
	override float radius() { return radius_; }
	override immutable(PolarCoord)[] vertexes() { return roundObject!(12, false); }

	override float lifetime() { return timeToBurst < 0 ? 0 : float.infinity; }

	Cell daughter1;
	Cell daughter2;

	int coronaviruses;
	int coronavirusesSpawned;

	override GameObject replacement() {
		if(daughter2 !is null) {
			auto d = daughter2;
			daughter2 = null;
			return d;
		}
		if(daughter1 !is null) {
			auto d = daughter1;
			daughter1 = null;
			return d;
		}

		if(infected) {
			if(this.coronavirusesSpawned < this.coronaviruses) {
				auto ndx = dx * 1.5 * cos(a);
				auto ndy = dy * 1.5 * sin(a);
				a += 2.0 * PI / cast(float) this.coronaviruses;
				this.coronavirusesSpawned++;
				return new CoronaVirus(x, y, ndx, ndy);
			}
		}

		return null;
	}

	bool infected = false;

	override void draw(ScreenPainter* painter) {
		painter.outlineColor = Color.red;
		painter.fillColor = Color.red;
		super.draw(painter);
	}

	override void move() {
		if(!shot && radius_ < 24.0) {
			radius_ += 0.05;
		} else {
			if(shot || infected || count < 20) {
				timeToBurst--;
				if(timeToBurst == 0) {
					count--;
					if(infected) {
						coronaviruses += cast(int) (this.radius_ / 6);
					} else if(!shot) {
						if(radius_ >= 12.0)
							daughter1 = new Cell(12, x + dx * 2 + radius_ / 2, y + dy * 2 + radius_ / 2, dx, dy);
						if(radius_ >= 24.0)
							daughter2 = new Cell(12, x - dx * 2 - radius_ / 2, y - dy * 2 - radius_ / 2, -dx, -dy);
					}
				}
			}
		}

		super.move();
	}

	bool shot;

	override void getHitBy(GameObject o) {
		if(false && (cast(Ship) o || cast(Cell) o)) {
			// we bounce off ships and cells
			auto tdx = this.dx;
			auto tdy = this.dy;
			this.dx = o.dx;
			this.dy = o.dy;
			o.dx = tdx;
			o.dy = tdy;
		} else if(cast(CoronaVirus) o) {
			this.infected = true;
			if(this.coronaviruses < 3)
				this.coronaviruses++;
		} else if(cast(Antibody) o) {
			shot = true;
			timeToBurst = 1;
		}
	}
}

class CoronaVirus : GameObject {
	this(float x, float y, float dx, float dy) {
		this.x = x;
		this.y = y;
		this.dx = dx;
		this.dy = dy;
	}
	override float radius() { return 6; }
	override immutable(PolarCoord)[] vertexes() { return roundObject!(12, true); }

	bool alive = true;
	override float lifetime() { return alive ? float.infinity : 0; }

	override void getHitBy(GameObject o) {
		if(auto cell = cast(Cell) o) {
			alive = false;
		} else if(cast(Ship) o) {
			alive = false;
		} else if(cast(Antibody) o) {
			alive = false;
		}
	}
}

class Antibody : GameObject {
	this(GameObject shooter) {
		auto speed = 5.0;
		auto radius = shooter.radius();
		this.x = shooter.x + (radius + this.radius + 0.2) * cos(shooter.a) + shooter.dx;
		this.y = shooter.y + (radius + this.radius + 0.2) * sin(shooter.a) + shooter.dy;
		this.dx = shooter.dx + speed * cos(shooter.a);
		this.dy = shooter.dy + speed * sin(shooter.a);

		lifetime_ = 64;
	}

	override float radius() { return 2; }
	override immutable(PolarCoord)[] vertexes() { return roundObject!(4, false); }

	override void move() {
		if(lifetime_ <= 0) return;
		lifetime_--;
		super.move();
	}

	int lifetime_;

	override float lifetime() { return lifetime_; }

	override void getHitBy(GameObject o) {
		lifetime_ = 0;
	}
}

GameObject[] gameObjects;

void main() {
	auto window = new SimpleWindow(512, 512, "Asteroids");

	auto playerShip = new Ship();
	gameObjects ~= playerShip;
	gameObjects ~= new Cell(12, 400, 200, 0.1, 0.1);
	gameObjects ~= new Cell(12, 400, 200, 0.05, -0.08);
	gameObjects ~= new CoronaVirus(200, 200, 0.9, 0.9);
	gameObjects ~= new CoronaVirus(200, 300, 0.9, 0.9);
	gameObjects ~= new CoronaVirus(200, 330, -0.9, 0.9);

	bool turningLeft;
	bool turningRight;
	bool thrusting;

	bool firing;

	int frameUpdate = 6;

	window.eventLoop(1000 / 60,
		delegate(KeyEvent ke) {
			with(Key)
			switch(ke.key) {
				case Left:
					turningLeft = ke.pressed;
				break;
				case Right:
					turningRight = ke.pressed;
				break;
				case Up:
					thrusting = ke.pressed;
				break;
				case Down:
					if(ke.pressed) {
						playerShip.hp -= 600;
						if(playerShip.hp < 0)
							playerShip.hp = 0;
					}
				break;
				case Space:
					if(playerShip.cooldown <=0) {
						gameObjects ~= new Antibody(playerShip);
						playerShip.cooldown = 3 * frameUpdate;
					}
				break;
				default:
					// this space deliberately left blank
			}
		},

		delegate() {
			auto painter = window.draw();
			painter.fillColor = Color.black;
			painter.outlineColor = Color.black;

			if(playerShip.hp < 1200) playerShip.hp ++;
			if(playerShip.cooldown) playerShip.cooldown --;

			painter.drawRectangle(Point(0, 0), window.width, window.height);

			painter.outlineColor = Color.white;

			if(turningLeft)
				playerShip.da -= 0.04 / frameUpdate;
			if(turningRight)
				playerShip.da += 0.04 / frameUpdate;
			if(thrusting) {
				playerShip.dx += cos(playerShip.a) / frameUpdate;
				playerShip.dy += sin(playerShip.a) / frameUpdate;
			}

			// update state
			foreach(obj; gameObjects) {
				obj.move();
				obj.draw(&painter);
			}

			// collision detect
			foreach(obj; gameObjects) {
				foreach(other; gameObjects) {
					if(other is obj) continue;
					auto deltaX = obj.x - other.x;
					auto deltaY = obj.y - other.y;
					auto sum = obj.radius + other.radius;
					if((deltaX * deltaX + deltaY * deltaY) < sum * sum) {
						//import std.stdio; writeln(obj, " hit ", other);
						obj.getHitBy(other);
					}
				}
			}

			// remove dead objects
			for(int i = 0; i < gameObjects.length; i++) {
				auto obj = gameObjects[i];

				if(obj.lifetime <= 0) {
					auto replacement = obj.replacement();
					if(replacement is null) {
						gameObjects[i] = gameObjects[$-1];
						gameObjects = gameObjects[0 .. $-1];
						version(WebAssembly) {} else
						gameObjects.assumeSafeAppend();
						i--;
					} else {
						gameObjects[i] = replacement;
						while((replacement = obj.replacement()) !is null) {
							gameObjects ~= replacement;
						}
					}
				}
			}
		}
	);
}
