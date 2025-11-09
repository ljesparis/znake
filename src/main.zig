const rl = @import("raylib");
const std = @import("std");
const Deque = @import("deque").Deque;

const green = rl.Color.init(173, 204, 96, 255); // green
const darkGreen = rl.Color.init(43, 51, 24, 255); // dark green

const cellSize = 30;
const cellCount = 25;
const offset = 70;

const windowWidth = cellSize * cellCount;
const windowHeight = cellSize * cellCount;
const mapWidth = windowWidth - offset * 2;
const mapHeight = windowHeight - offset * 2;
const mapLineTick = 5;

const Snake = struct {
    body: Deque(rl.Vector2),
    direction: rl.Vector2,
    growth: bool,
    allocator: *std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator) anyerror!Self {
        var self: Self = .{
            .allocator = allocator,
            .direction = .{ .x = 1, .y = 0 },
            .growth = false,
            .body = try Deque(rl.Vector2).init(allocator.*),
        };

        try self.reset();

        return self;
    }

    pub fn reset(self: *Self) anyerror!void {
        var i = self.body.len();
        while (i > 0) {
            _ = self.body.popBack();
            i -= 1;
        }

        try self.body.pushBack(rl.Vector2.init(7, 5));
        try self.body.pushBack(rl.Vector2.init(6, 5));
        try self.body.pushBack(rl.Vector2.init(5, 5));
        self.direction = .{ .x = 1, .y = 0 };
    }

    pub fn deinit(self: *Self) void {
        self.body.deinit();
    }

    pub fn draw(self: *Self) void {
        var it = self.body.iterator();
        while (it.next()) |bodyPart| {
            rl.drawRectangleRounded(rl.Rectangle.init(
                offset + bodyPart.x * cellSize,
                offset + bodyPart.y * cellSize,
                cellSize,
                cellSize,
            ), 0.5, 6, darkGreen);
        }
    }

    pub fn update(self: *Self) anyerror!void {
        try self.body.pushFront(rl.math.vector2Add(self.head().*, self.direction));
        if (self.growth) {
            self.growth = false;
        } else {
            _ = self.body.popBack();
        }
    }

    pub fn onKeyPressed(self: *Self, key: rl.KeyboardKey) void {
        if (key == .a and self.direction.x != 1) {
            self.direction = .{ .x = -1, .y = 0 };
        } else if (key == .d and self.direction.x != -1) {
            self.direction = .{ .x = 1, .y = 0 };
        } else if (key == .w and self.direction.y != 1) {
            self.direction = .{ .x = 0, .y = -1 };
        } else if (key == .s and self.direction.y != -1) {
            self.direction = .{ .x = 0, .y = 1 };
        }
    }

    pub fn head(self: *Self) *rl.Vector2 {
        return self.body.front().?;
    }
};

const Apple = struct {
    position: rl.Vector2,

    const Self = @This();

    pub fn init() Self {
        return .{ .position = generateRandomVector() };
    }

    pub fn changePosition(self: *Self, snake: *Snake) void {
        self.position = generateRandomVector();
        var it = snake.body.iterator();
        while (it.next()) |el| {
            if (self.position.equals(el.*) > 0) {
                self.changePosition(snake);
            }
        }
    }

    fn generateRandomVector() rl.Vector2 {
        var prng = std.Random.DefaultPrng.init(@as(u64, @bitCast(std.time.milliTimestamp())));
        const rand = prng.random();
        const x = rand.intRangeAtMost(i32, 0, mapWidth / cellSize - 1);
        const y = rand.intRangeAtMost(i32, 0, mapHeight / cellSize - 1);
        std.debug.print("apple  (x: {}, y: {}) \n", .{ x, y });
        return .{ .x = @floatFromInt(x), .y = @floatFromInt(y) };
    }

    pub fn draw(self: *Self) void {
        rl.drawRectangleRounded(rl.Rectangle.init(
            offset + self.position.x * cellSize,
            offset + self.position.y * cellSize,
            cellSize,
            cellSize,
        ), 0.5, 2, darkGreen);
    }
};

const Game = struct {
    snake: Snake,
    apple: Apple,
    running: bool = true,
    points: u16 = 0,

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator) anyerror!Self {
        return .{
            .snake = try .init(allocator),
            .apple = .init(),
        };
    }

    pub fn deinit(self: *Self) void {
        self.snake.deinit();
    }

    pub fn draw(self: *Self) anyerror!void {
        self.snake.draw();
        self.apple.draw();

        var buffer: [32:0]u8 = undefined;
        const slice = try std.fmt.bufPrint(&buffer, "Score: {}", .{self.points});
        buffer[slice.len] = 0;
        const cstr: [:0]const u8 = buffer[0..slice.len :0];
        rl.drawText(cstr, offset, offset / 2, 20, darkGreen);
    }

    pub fn update(self: *Self) anyerror!void {
        if (!self.running) return;

        try self.snake.update();

        // check collision with apple
        if (rl.math.vector2Equals(self.snake.head().*, self.apple.position) > 0) {
            self.snake.growth = true;
            self.apple.changePosition(&self.snake);
            self.points += 1;
        }

        // check collision with any wall
        const head = self.snake.body.popFront().?;
        std.debug.print("Snake(x: {}, y: {})\n", .{ head.x, head.y });
        if (head.x == mapWidth / cellSize or head.x == -1 or head.y == -1 or head.y == mapHeight / cellSize) {
            try self.gameOver();
            return;
        }

        // check collision with tail
        var it = self.snake.body.iterator();
        while (it.next()) |el| {
            if (el.equals(head) > 0) {
                try self.gameOver();
                return;
            }
        }
        try self.snake.body.pushFront(head);
    }

    pub fn gameOver(self: *Self) anyerror!void {
        self.apple.changePosition(&self.snake);
        try self.snake.reset();
        self.points = 0;
        self.running = false;
    }

    pub fn onKeyPressed(self: *Self, key: rl.KeyboardKey) void {
        self.snake.onKeyPressed(key);

        if (!self.running) {
            switch (key) {
                .a => self.running = true,
                .s => self.running = true,
                .d => self.running = true,
                .w => self.running = true,
                else => {},
            }
        }
    }
};

var lastUpdateTime: f64 = 0.0;

fn eventTriggered(interval: f64) bool {
    const currentTime: f64 = rl.getTime();
    if (currentTime - lastUpdateTime >= interval) {
        lastUpdateTime = currentTime;
        return true;
    }
    return false;
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("TEST FAIL");
    }

    var allocator = gpa.allocator();

    rl.initWindow(cellSize * cellCount, cellSize * cellCount, "Retro snake");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var game: Game = try .init(&allocator);
    defer game.deinit();

    while (!rl.windowShouldClose()) {
        if (eventTriggered(0.2)) {
            try game.update();
        }

        game.onKeyPressed(rl.getKeyPressed());

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(green);
        rl.drawRectangleLinesEx(rl.Rectangle.init(
            offset,
            offset,
            mapWidth,
            mapHeight,
        ), mapLineTick, darkGreen);
        try game.draw();
    }
}
