const std = @import("std");
const RL = @cImport({
    @cInclude("raylib.h");
});

// 3 bits
// 0 = unopen 1;
// 1 = unopen 2;
// 2 = unopen 3;
// 3 = unopen 4;
// 4 = unopen 5;
// 5 = unopen 6;
// 6 = unopen 7;
// 7 = unopen 8;

// 3 bits
// 10 = open
// 11 = bomb
// 12 = flag
const Tile = packed struct {
    count: u4,
    isOpen: bool,
    isBomb: bool,
    isFlag: bool,
    const Self = @This();
    fn Empty() Self {
        return Self{
            .count = 0,
            .isOpen = false,
            .isBomb = false,
            .isFlag = false,
        };
    }
};

const Vec2 = struct {
    x: u8,
    y: u8,
};


fn arrayContainsVec(arr: []const Vec2, tar: Vec2) bool {
    for(arr) |vec| {
        if(vec.x == tar.x and
            vec.y == tar.y)
            return true;
    }
    return false;
}

const Board = struct {
    data: [19][19]Tile,
    started: bool,
    isDead: bool,
    const Self = @This();
    fn create() Self {
        return Self{
            .data = undefined,
            .started = false,
            .isDead = false,
        };
    }
    fn clear(this: *Self) void {
        this.started = false;
        this.isDead = false;
    }
    fn get(this: Self, x: usize, y: usize) Tile {
        return this.data[x][y];
    }
    fn set(this: *Self, x: usize, y: usize) *Tile {
        return &this.data[x][y];
    }
    fn revealTile(this: *Self, x: usize, y: usize) void {
        {
            var cur = this.set(x, y);
            if (cur.isBomb) {
                this.isDead = true;
                return;
            }
            if (cur.count != 0) {
                cur.isOpen = true;
                return;
            }
        }
        var buffer: [4096 * 2]u8 = undefined;
        var FBA = std.heap.FixedBufferAllocator.init(&buffer);
        const allocator = FBA.allocator();
        var visited = std.ArrayList(Vec2).init(allocator);
        var toVisit = std.ArrayList(Vec2).init(allocator);
        toVisit.append(Vec2{
            .x = @intCast(x),
            .y = @intCast(y),
        }) catch return;
        while (true) {
            const pos = toVisit.pop();
            visited.append(pos) catch break;
            const hasLeft = pos.x != 0;
            const hasRight = pos.x != 18;
            const hasUp = pos.y != 18;
            const hasDown = pos.y != 0;
            if (this.get(pos.x, pos.y).count == 0) {
                if (hasLeft) {
                    const newPos = Vec2{
                        .x = pos.x - 1,
                        .y = pos.y,
                    };
                    if (!arrayContainsVec(visited.items, newPos))
                        toVisit.append(newPos) catch break;
                    if (hasUp) {
                        const newerPos = Vec2{
                            .x = pos.x - 1,
                            .y = pos.y + 1,
                        };
                        if (!arrayContainsVec(visited.items, newerPos))
                            toVisit.append(newerPos) catch break;
                    }
                    if (hasDown) {
                        const newerPos = Vec2{
                            .x = pos.x - 1,
                            .y = pos.y - 1,
                        };
                        if (!arrayContainsVec(visited.items, newerPos))
                            toVisit.append(newerPos) catch break;
                    }
                }
                if (hasRight) {
                    const newPos = Vec2{
                        .x = pos.x + 1,
                        .y = pos.y,
                    };
                    if (!arrayContainsVec(visited.items, newPos)) {
                        toVisit.append(newPos) catch break;
                    }
                    if (hasUp) {
                        const newerPos = Vec2{
                            .x = pos.x + 1,
                            .y = pos.y + 1,
                        };
                        if (!arrayContainsVec(visited.items, newerPos)) {
                            toVisit.append(newerPos) catch break;
                        }
                    }
                    if (hasDown) {
                        const newerPos = Vec2{
                            .x = pos.x + 1,
                            .y = pos.y - 1,
                        };
                        if (!arrayContainsVec(visited.items, newerPos)) {
                            toVisit.append(newerPos) catch break;
                        }
                    }
                }
                if (hasDown) {
                    const newPos = Vec2{
                        .x = pos.x,
                        .y = pos.y - 1,
                    };
                    if (!arrayContainsVec(visited.items, newPos)) {
                        toVisit.append(newPos) catch break;
                    }
                }
                if (hasUp) {
                    const newPos = Vec2{
                        .x = pos.x,
                        .y = pos.y + 1,
                    };
                    if (!arrayContainsVec(visited.items, newPos)) {
                        toVisit.append(newPos) catch break;
                    }
                }
            }
            this.set(pos.x, pos.y).isOpen = true;
            if (toVisit.items.len == 0)
                break;
        }
    }
    fn generateBoard(this: *Self, rand: std.rand.Random, bombsToGenerate: usize, xc: usize, yc: usize) void {
        this.data = [1][19]Tile{[1]Tile{Tile.Empty()} ** 19} ** 19;
        var curBombsToGenerate = bombsToGenerate;
        while (curBombsToGenerate > 0) {
            while (true) {
                const x = rand.intRangeLessThan(usize, 0, 19);
                const y = rand.intRangeLessThan(usize, 0, 19);
                if (x == xc and y == yc)
                    continue;
                const tile = this.set(x, y);
                if (tile.isBomb)
                    continue;
                tile.isBomb = true;
                this.onBombAdded(x, y);
                break;
            }
            curBombsToGenerate -= 1;
        }
    }
    fn onBombAdded(this: *Self, x: usize, y: usize) void {
        const hasLeft = x != 0;
        const hasRight = x != 18;
        const hasUp = y != 18;
        const hasDown = y != 0;
        if (hasLeft) {
            this.set(x - 1, y).count += 1;
            if (hasUp) {
                this.set(x - 1, y + 1).count += 1;
            }
            if (hasDown) {
                this.set(x - 1, y - 1).count += 1;
            }
        }
        if (hasRight) {
            this.set(x + 1, y).count += 1;
            if (hasUp) {
                this.set(x + 1, y + 1).count += 1;
            }
            if (hasDown) {
                this.set(x + 1, y - 1).count += 1;
            }
        }
        if (hasUp)
            this.set(x, y + 1).count += 1;
        if (hasDown)
            this.set(x, y - 1).count += 1;
    }
};

const tileSize = 48;

pub fn main() void {
    RL.InitWindow(912, 912, "Minesweeper");
    RL.SetTargetFPS(60);
    const darkGrassColor = RL.GetColor(0x6F6F6FFF);
    const lightGrassColor = RL.GetColor(0x8F8F8FFF);
    const sandColor = RL.GetColor(0xBFBFBFFF);
    const whiteColor = RL.GetColor(0xFFFFFFFF);
    const countToCol = [_]RL.Color{
        RL.GetColor(0x0000FFFF), // blue
        RL.GetColor(0x007F00FF), // green
        RL.GetColor(0xFF0000FF), // red
        RL.GetColor(0x00007FFF), // dark blue
        RL.GetColor(0x7F0000FF), // dark red
        RL.GetColor(0x007F7FFF), // cyan
        RL.GetColor(0x000000FF), // black
        RL.GetColor(0xFFFF00FF), // yellow
    };
    const flag_texture: RL.Texture2D = RL.LoadTexture("./textures/flag.png");
    const bomb_texture: RL.Texture2D = RL.LoadTexture("./textures/bomb.png");
    defer RL.UnloadTexture(bomb_texture);
    defer RL.UnloadTexture(flag_texture);
    var rando = initRandBlk: {
        var sm = std.rand.SplitMix64.init(@bitCast(std.time.microTimestamp()));
        break :initRandBlk std.rand.Xoshiro256.init(sm.next());
    };
    const rand = rando.random();
    var board = Board.create();
    while (!RL.WindowShouldClose()) {
        RL.BeginDrawing();
        if (RL.IsMouseButtonPressed(RL.MOUSE_BUTTON_RIGHT)) {
            const pos = RL.GetMousePosition();
            const x: u32 = @as(u32, @intFromFloat(pos.x)) / tileSize;
            const y: u32 = @as(u32, @intFromFloat(pos.y)) / tileSize;
            if (board.started and !board.isDead) {
                const tile = board.set(x, y);
                tile.isFlag = !tile.isFlag;
            }
        }
        if (RL.IsMouseButtonPressed(RL.MOUSE_BUTTON_LEFT)) {
            const pos = RL.GetMousePosition();
            const x: u32 = @as(u32, @intFromFloat(pos.x)) / tileSize;
            const y: u32 = @as(u32, @intFromFloat(pos.y)) / tileSize;
            if (!board.started) {
                board.generateBoard(rand, 65, x, y);
                board.started = true;
            }
            if (!board.isDead and !board.get(x, y).isFlag)
                board.revealTile(x, y);
        }
        RL.ClearBackground(sandColor);
        var x: u32 = 0;
        while (x < 19) {
            var y: u32 = 0;
            while (y < 19) {
                const xp: i32 = @intCast(x * tileSize);
                const yp: i32 = @intCast(y * tileSize);
                const tile = board.get(x, y);
                if (board.started and tile.isOpen) {
                    if (tile.count != 0) {
                        const text = [2]u8{ '0' + @as(u8, @intCast(tile.count)), 0 };
                        RL.DrawText(@ptrCast(&text), xp + 14, yp + 6, 40, countToCol[@intCast(tile.count - 1)]);
                    }
                } else {
                    RL.DrawRectangle(xp, yp, tileSize, tileSize, if ((x & 1) ^ (y & 1) != 0) darkGrassColor else lightGrassColor);
                    if (board.started and tile.isFlag and !(board.isDead and tile.isBomb))
                        RL.DrawTextureEx(flag_texture, .{
                            .x = @floatFromInt(xp),
                            .y = @floatFromInt(yp)
                        }, 0, 3, whiteColor);
                }
                if (board.isDead and tile.isBomb)
                    RL.DrawTextureEx(bomb_texture, .{
                        .x = @floatFromInt(xp),
                        .y = @floatFromInt(yp)
                    }, 0, 3, whiteColor);
                y += 1;
            }
            x += 1;
        }
        if(board.isDead) {
            RL.DrawRectangle(0, 0, 912, 912, RL.GetColor(0x0000007F));
            RL.DrawText("You died!", 157, 200, 137, whiteColor);
            RL.DrawText("Press ENTER to try again.", 237, 460, 32, whiteColor);
            if(RL.IsKeyPressed(RL.KEY_ENTER)) {
                board.clear();
            }
        }
        RL.EndDrawing();
    }
    RL.CloseWindow();
}
