
module cache_controller (
    input  logic clk,        // System clock
    input  logic rst,        // Active-low reset signal
    input  logic read_req,   // Read request from CPU
    input  logic write_req,  // Write request from CPU
    input  logic [23:0] addr,// Memory address from CPU
    input  logic mem_ready,  // Memory system ready signal
    output logic evict,      // Indicates block eviction in progress
    output logic allocate,   // Indicates block allocation in progress
    output logic write_back  // Indicates write-back operation needed
);

    // FSM state definitions
    // Defines all possible states for the cache controller
    typedef enum logic [3:0] {
        IDLE,           // Waiting for requests
        CHECK_READ,     // Checking if read is hit/miss
        READ_HIT,      // Handling cache read hit
        READ_MISS,     // Handling cache read miss
        CHECK_WRITE,   // Checking if write is hit/miss
        WRITE_HIT,     // Handling cache write hit
        WRITE_MISS,    // Handling cache write miss
        EVICT,         // Evicting a cache block
        ALLOCATE_BLOCK // Allocating a new cache block
    } state_t;

    state_t current_state, next_state;

    // Cache storage arrays
    logic [18:0] tag_array[0:127][0:3];   // Stores tags: 128 sets × 4 ways
    logic        valid_array[0:127][0:3];  // Valid bits for each block
    logic        dirty_array[0:127][0:3];  // Dirty bits for write-back
    logic [1:0]  age_array[0:127][0:3];    // LRU counters (2 bits per block)

    // Address decomposition
    logic [6:0] index;    // Cache set index
    logic [18:0] tag;     // Tag bits from address

    // Extract index and tag from address
    assign index = addr[12:6];   // 7 bits for 128 sets
    assign tag   = addr[23:5];   // 19 bits for tag

    // Cache operation signals
    logic hit;            // Indicates cache hit
    logic [1:0] hit_way;  // Way number where hit occurred
    logic [1:0] lru_way;  // Way selected for replacement

    // Combinational logic for hit detection and LRU way selection
    always_comb begin
        hit = 0;
        hit_way = 2'd0;
        lru_way = 2'd0;

        // Check all ways for a hit
        for (int j = 0; j < 4; j++) begin
            if (valid_array[index][j] && tag_array[index][j] == tag) begin
                hit = 1;
                hit_way = j[1:0];
            end
        end

        // Find LRU way (with age = 11)
        for (int j = 0; j < 4; j++) begin
            if (age_array[index][j] == 2'b11)
                lru_way = j[1:0];
        end
    end

    // State register with asynchronous reset
    always_ff @(posedge clk or negedge rst) begin
        if (!rst)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // Next state and output logic
    always_comb begin
        // Default assignments
        next_state = current_state;
        evict = 0;
        allocate = 0;
        write_back = 0;

        case (current_state)
            // Handle state transitions and outputs
            IDLE: begin
                if (read_req)
                    next_state = CHECK_READ;
                else if (write_req)
                    next_state = CHECK_WRITE;
            end

            CHECK_READ: next_state = hit ? READ_HIT : READ_MISS;
            READ_HIT: next_state = IDLE;
            READ_MISS: next_state = EVICT;
            CHECK_WRITE: next_state = hit ? WRITE_HIT : WRITE_MISS;
            WRITE_HIT: next_state = IDLE;
            WRITE_MISS: next_state = EVICT;

            EVICT: begin
                evict = 1;
                if (dirty_array[index][lru_way])
                    write_back = 1;
                next_state = ALLOCATE_BLOCK;
            end

            ALLOCATE_BLOCK: begin
                allocate = 1;
                if (mem_ready)
                    next_state = IDLE;
                // Otherwise: stays in ALLOCATE_BLOCK
            end
        endcase
    end

    // Cache update logic
    always_ff @(posedge clk) begin
        // Handle block allocation
        if (current_state == ALLOCATE_BLOCK && mem_ready) begin
            // Update cache entry
            tag_array[index][lru_way]   <= tag;
            valid_array[index][lru_way] <= 1;
            dirty_array[index][lru_way] <= write_req ? 1 : 0;

            // Update LRU counters
            for (int k = 0; k < 4; k++) begin
                if (k == lru_way)
                    age_array[index][k] <= 2'b00;  // Youngest
                else if (age_array[index][k] < 2'b11)
                    age_array[index][k] <= age_array[index][k] + 1;  // Age other blocks
            end
        end

        // Handle cache hits
        if ((current_state == READ_HIT || current_state == WRITE_HIT) && hit) begin
            // Update LRU counters on hit
            for (int k = 0; k < 4; k++) begin
                if (k == hit_way)
                    age_array[index][k] <= 2'b00;  // Accessed block becomes youngest
                else if (age_array[index][k] < 2'b11)
                    age_array[index][k] <= age_array[index][k] + 1;  // Age other blocks
            end

            // Set dirty bit on write hit
            if (current_state == WRITE_HIT)
                dirty_array[index][hit_way] <= 1'b1;
        end
    end

endmodule