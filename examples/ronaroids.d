// ./ronaroids --port 5000
module dconf.ronaroids.base;

/+
	Gonna make the webasm thing just forward input things to the server.

	The server will be where the game logic actually runs.

	It tells the webasm state updates periodically and it then lerps to draw.


	When you connect to the server, it assigns you an id and tells you the positions
	as of the starting frame number.

	When the server sees no connections, it stops the timer and resets.
+/

import std.math;


bool collidesWith(ref GameObject a, ref GameObject b) {
	import arsd.color;
	auto at = gameObjectTypes[a.type];
	auto bt = gameObjectTypes[b.type];
	Rectangle r1 = Rectangle(cast(int)(a.x - at.radius), cast(int)(a.y - at.radius), cast(int)(a.x + at.radius), cast(int)(a.y + at.radius));
	Rectangle r2 = Rectangle(cast(int)(b.x - bt.radius), cast(int)(b.y - bt.radius), cast(int)(b.x + bt.radius), cast(int)(b.y + bt.radius));

	if(!r1.overlaps(r2))
		return false;

	// FIXME: get more precise

	return true;
}

void shipGotShot(ref GameObject ship) {
	ship.hp -= 100;
}

void asteroidGotShot(ref GameObject asteroid) {
	asteroid.hp -= 400;
}

void shipHitAsteroid(ref GameObject ship, ref GameObject asteroid) {
	ship.hp -= 600;
	asteroid.hp -= 600;
}

class RonaroidsGame {
	GameObject[] ships;
	GameObject[] bullets;
	GameObject[] asteroids;
	int frameNumber;
	byte players;

	void replaceState(const(ubyte)[] update) {
		int idx = 0;
		players = update[idx++];
		frameNumber = 0;
		frameNumber |= update[idx++] << 0;
		frameNumber |= update[idx++] << 8;
		frameNumber |= update[idx++] << 16;
		frameNumber |= update[idx++] << 24;

		ships.length = update[idx++];
		ships[] = cast(GameObject[]) update[idx .. idx + (cast(ubyte[]) ships).length];
		idx += (cast(ubyte[]) ships).length;

		bullets.length = update[idx++];
		bullets[] = cast(GameObject[]) update[idx .. idx + (cast(ubyte[]) bullets).length];
		idx += (cast(ubyte[]) bullets).length;

		asteroids.length = update[idx++];
		asteroids[] = cast(GameObject[]) update[idx .. idx + (cast(ubyte[]) asteroids).length];
		idx += (cast(ubyte[]) asteroids).length;

	}

	ubyte[] getStateReplacement() {
		ubyte[] data;

		data ~= players;
		data ~= (frameNumber >> 0) & 0xff;
		data ~= (frameNumber >> 8) & 0xff;
		data ~= (frameNumber >> 16) & 0xff;
		data ~= (frameNumber >> 24) & 0xff;

		data ~= cast(ubyte) ships.length;
		data ~= cast(ubyte[]) ships;

		data ~= cast(ubyte) bullets.length;
		data ~= cast(ubyte[]) bullets;

		data ~= cast(ubyte) asteroids.length;
		data ~= cast(ubyte[]) asteroids;

		return data;
	}

	this() {
		ships.reserve(32);
		bullets.reserve(128);
		asteroids.reserve(64);
	}

	ubyte addPlayer() {
		ubyte newPlayer = ++players;
		ships ~= GameObject(newPlayer, 0, 1200, 0, 0, 100, 100, 0, 0, 0, 0);
		asteroids ~= GameObject(0, 2, 1200, 0, 0, 300, 300, 0, 0.2, -0.2, 0);
		return newPlayer;
	}

	// returns if it is still alive
	bool updateObject(ref GameObject obj) {
		if(obj.hp <= 0)
			return false;

		obj.x += obj.dx;
		obj.y += obj.dy;
		obj.a += obj.da;

		if(obj.cooldown)
			obj.cooldown--;

		if(obj.x > 512)
			obj.x -= 512;
		if(obj.x < 0)
			obj.x += 512;
		if(obj.y > 512)
			obj.y -= 512;
		if(obj.y < 0)
			obj.y += 512;

		return true;
	}

	void executeControls(ref GameObject obj) {
		// left, right, up, space
		if(obj.controlState & 1)
			obj.da -= 0.01;
		if(obj.controlState & 2)
			obj.da += 0.01;

		if(obj.controlState & 4) {
			obj.dx += 0.10 * cos(obj.a);
			obj.dy += 0.10 * sin(obj.a);
		}

		// control caps to ease collision detection
		// and keep players from going out of control
		// (even if it is bad physics lol)
		if(obj.da < -0.2) obj.da = -0.2;
		if(obj.da > 0.2) obj.da = 0.2;
		if(obj.dx > 8) obj.dx = 8;
		if(obj.dx < -8) obj.dx = -8;
		if(obj.dy > 8) obj.dy = 8;
		if(obj.dy < -8) obj.dy = -8;

		if((obj.controlState & 8) && obj.cooldown == 0) {
			obj.cooldown = 10;
			bullets ~= GameObject(
				obj.owner, 1, 100, 0, 0,

				obj.x + 16 * 1.5 * cos(obj.a),
				obj.y + 16 * 1.5 * sin(obj.a),
				0,

				obj.dx + 2 * cos(obj.a),
				obj.dy + 2 * sin(obj.a),
				0
			);
		}
	}

	void updateAll() {
		frameNumber++;

		foreach(ref obj; ships)
			executeControls(obj);

		void updateList(ref GameObject[] list) {
			for(int oid = 0; oid < list.length; oid++)
				if(!updateObject(list[oid])) {
					list[oid] = list[$ - 1];
					list = list[0 .. $-1];
					list.assumeSafeAppend();
				}
		}

		updateList(ships);
		updateList(asteroids);
		updateList(bullets);

		// collision detect
		bulletLoop:
		for(int bid = 0; bid < bullets.length; bid++) {
			void removeBullet() {
				bullets[bid] = bullets[$ - 1];
				bullets = bullets[0 .. $-1];
				bullets.assumeSafeAppend();
				bid--;
			}
			foreach(ref ship; ships) {
				if(bullets[bid].collidesWith(ship)) {
					removeBullet();
					ship.shipGotShot();

					continue bulletLoop;
				}
			}
			foreach(ref asteroid; asteroids) {
				// bullet hit 'roid
				if(bullets[bid].collidesWith(asteroid)) {
					removeBullet();
					asteroid.asteroidGotShot(); // can this add more asteroids?

					continue bulletLoop;
				}
			}

			// bullets cannot hit other bullets so the res of this blank
		}

		foreach(ref ship; ships) {
			foreach(ref asteroid; asteroids) {
				if(ship.collidesWith(asteroid)) {
					shipHitAsteroid(ship, asteroid); // can this add debris?
				}
			}
		}
	}
}

struct PolarCoord {
	float a = 0.0f;
	float r = 0.0f;
}

private PolarCoord[] roundObject(int segmentsCount, bool convex) {
	assert(__ctfe);
	PolarCoord[] items;
	float a = 0;
	float step = PI * 2 / segmentsCount;
	foreach(i; 0 .. segmentsCount) {
		items ~= PolarCoord(a, (!convex || i%2) ? 1.0 : 0.5);
		a += step;
	}

	items ~= items[0];

	return items;
}

static immutable PolarCoord[] shipVertexes = [
	PolarCoord(0.0, 0),
	PolarCoord(PI - PI / 6, 1.0),
	PolarCoord(0, 1.0),
	PolarCoord(PI + PI / 6, 1.0),
	PolarCoord(0.0, 0)
];
static immutable PolarCoord[] asteroidVertexes = roundObject(12, true);
static immutable PolarCoord[] bulletVertexes = roundObject(12, false);

immutable struct GameObjectDefinition {
	PolarCoord[] vertexes;
	float radius;
}

static immutable GameObjectDefinition[] gameObjectTypes = [
	GameObjectDefinition(shipVertexes, 16),
	GameObjectDefinition(bulletVertexes, 4),
	GameObjectDefinition(asteroidVertexes, 24),
	GameObjectDefinition(asteroidVertexes, 12),
	GameObjectDefinition(asteroidVertexes, 6),
];

struct GameObject {
	this(typeof(this.tupleof) args) {
		this.tupleof = args;
	}

	align(1):
	ubyte owner; // 0 == neutral
	ubyte type; // ship, bullet, asteroids of various sizes.
	short hp;

	ushort controlState;
	short cooldown;

	float x, y, a;
	float dx, dy, da;
}

struct GameUpdate {
	int time;
	GameObject[] state;
}

struct ControlUpdate {
	int time; // this is likely ignored as the server is the source of truth
	ushort newControlState;
	ushort newControlStateMask; // tells which ones are actually changed
	ubyte owner;
}

version(WebAssembly)
	version=client;

version(client) {

import arsd.simpledisplay;
import arsd.http2;

void main() {
	auto window = new SimpleWindow(512, 512);

	auto game = new RonaroidsGame();

	ubyte myNumber;

	// myNumber = game.addPlayer();

	auto ws = new WebSocket(Uri("ws://arsdnet.net:5000/"));

	ws.onmessage = (in ubyte[] data) {
		// we send control updates
		// but receive state dumps.
		// except for the first connection, that's what assigns you a player id

		if(data.length == 1) {
			myNumber = data[0];
			import std.stdio; writeln("Player ", myNumber);
		} else {
			game.replaceState(data);
		}
	};

	ws.connect();

	ws.addToSimpledisplayEventLoop!()(window);

	window.onClosing = {
		ws.close();
	};

	// FIXME: close the websocket on window closing

	enum fps = 80; // for render, can be variable really

	void sendControlUpdate(ushort state, bool set) {
		ControlUpdate cu;
		cu.time = game.frameNumber;
		if(set)
			cu.newControlState |= state;
		else
			cu.newControlState &= ~state;
		cu.newControlStateMask = state;
		cu.owner = myNumber;

		foreach(ref ship; game.ships)
			if(ship.owner == myNumber) {
				ship.controlState &= ~cu.newControlStateMask;
				ship.controlState |= cu.newControlState;
				break; // there's only one ship you can have
			}

		ws.send((cast(ubyte*) &cu)[0 .. cu.sizeof]);
	}

	int counter = 0;
	import core.time;
	MonoTime start;

	__gshared static MonoTime nextUpdate;
	__gshared static MonoTime now;

	now = MonoTime.currTime;
	nextUpdate = now + 50.msecs;

	window.eventLoop(1000 / fps,
		delegate (KeyEvent ev) {
			switch(ev.key) {
				case Key.Left:
					sendControlUpdate(1, ev.pressed);
				break;
				case Key.Right:
					sendControlUpdate(2, ev.pressed);
				break;
				case Key.Up:
					sendControlUpdate(4, ev.pressed);
				break;
				case Key.Space:
					sendControlUpdate(8, ev.pressed);
				break;

				default:
			}
		},
		() {
			while((now = MonoTime.currTime) >= nextUpdate) {
				nextUpdate = nextUpdate + 50.msecs;
				counter++;
				if(counter == 20) {
					// version(linux) { import std.stdio; writeln(MonoTime.currTime - start); }
					counter = 0;
					start = MonoTime.currTime;

				}
				game.updateAll();
			}

			auto painter = window.draw();
			painter.fillColor = Color.black;
			painter.outlineColor = Color.black;
			painter.drawRectangle(Point(0, 0), Size(window.width, window.height));

			void drawObject(ref GameObject obj) {
				float lerp(float value, float delta) {
					return value + delta * (50 - (nextUpdate - now).total!"msecs") / 50;
				}

				if(obj.owner == myNumber) {
					painter.outlineColor = Color.green;
				} else {
					painter.outlineColor = Color.white;
				}

				auto type = gameObjectTypes[obj.type];

				Point[32] shipVertexes;
				foreach(i, vertex; type.vertexes) {
					shipVertexes[i] =
						Point(
							cast(int) (type.radius * vertex.r * cos(lerp(obj.a, obj.da) + vertex.a) + lerp(obj.x, obj.dx)),
							cast(int) (type.radius * vertex.r * sin(lerp(obj.a, obj.da) + vertex.a) + lerp(obj.y, obj.dy))
						);
				}

				painter.drawPolygon(shipVertexes[0 .. type.vertexes.length]);
			}

			painter.fillColor = Color.white;
			painter.outlineColor = Color.white;

			foreach(ref obj; game.ships) {
				drawObject(obj);
			}
			foreach(ref obj; game.asteroids) {
				drawObject(obj);
			}
			foreach(ref obj; game.bullets) {
				drawObject(obj);
			}

		}
	);
}

}


version(server):

import core.thread;

class GameThread : Thread {
	RonaroidsGame game;
	bool playersConnected;

	this() {
		game = new RonaroidsGame();
		super(&main);
	}

	ubyte addPlayer() {
		synchronized(game)
			return game.addPlayer();
	}

	void main() {
		import core.time;
		MonoTime start = MonoTime.currTime;

		MonoTime nextUpdate = MonoTime.currTime + 50.msecs;
		int counter = 0;
		while(playersConnected) {
			/+
			import core.sys.linux.timerfd;
			import core.sys.posix.unistd;
			auto fd = timerfd_create(CLOCK_MONOTONIC, 0);

			itimerspec value;

			const intervalInMilliseconds = 50;

                        value.it_value.tv_sec = cast(int) (intervalInMilliseconds / 1000);
                        value.it_value.tv_nsec = (intervalInMilliseconds % 1000) * 1000_000;

                        value.it_interval.tv_sec = cast(int) (intervalInMilliseconds / 1000);
                        value.it_interval.tv_nsec = (intervalInMilliseconds % 1000) * 1000_000;

			timerfd_settime(fd, 0, &value, null);

			ubyte[16] buf;
			read(fd, buf.ptr, buf.length);


			+/

			import core.time;

			auto now = MonoTime.currTime();
			if(now >= nextUpdate) {
				nextUpdate += 50.msecs;

				synchronized(game)
					game.updateAll();
			}


			/+
			counter++;
			if(counter == 20) {
				import std.stdio; writeln(begin - start);
				start = begin;
				counter = 0;
			}
			+/


			auto diff = nextUpdate - now;
			if(diff > 0.msecs) {
				import core.sys.posix.time;
				timespec tv;
				timespec rem;
				tv.tv_nsec = diff.total!"nsecs";

				nanosleep(&tv, &rem);
			}

			//sleep(diff);
		}
	}
}
