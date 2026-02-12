module Cache_Controller (
  input clk, rst_b,
  input read_req, write_req,
  input [23:0] address,  //adresa pe care o comparam cu ce e in cache prin tag, index
  input [511:0] valid, // spune daca data din cache este buna
  input [10:0] cache_tag [511:0],
  input [511:0] dirty_bits,
  input [1:0] age [511:0],
  input mem_ready, //Memoria principală și-a terminat operația cerută , un fel de delay

  output reg [1:0]hit_way, //care way a avut hit, in caz de hit 
  output reg valid_update, 
  output reg [10:0] cache_tag_update,
  output reg dirty_bit_update,

  output reg cache_read, cache_write,
  output reg mem_read,mem_write,
  output reg evict_line, write_back,
  output reg update_lru,
  output reg finish,
  output reg [1:0] lru_way //way selectat conform LRU
);

  localparam IDLE = 4'd0;
  localparam READ = 4'd1;
  localparam WRITE = 4'd2;
  localparam READ_HIT = 4'd3;
  localparam WRITE_HIT = 4'd4;
  localparam READ_MISS = 4'd5;
  localparam WRITE_MISS = 4'd6;
  localparam EVICT = 4'd7;
  localparam ALLOCATE = 4'd8;
  localparam FINISH = 4'd9;

  localparam OP_NONE  = 2'b00;
  localparam OP_READ  = 2'b10;
  localparam OP_WRITE = 2'b11;


  reg [3:0] st, st_next;
  reg [1:0] operation;

  wire [10:0] tag = address[23:13];    // 11 biti de tag
  wire [6:0] index = address[12:6];    // 7 biti de index -> 128 seturi

  wire hit0 = valid[index*4+0] && (cache_tag[index*4+0] == tag);
  wire hit1 = valid[index*4+1] && (cache_tag[index*4+1] == tag);
  wire hit2 = valid[index*4+2] && (cache_tag[index*4+2] == tag);
  wire hit3 = valid[index*4+3] && (cache_tag[index*4+3] == tag);

  wire hit = hit0 | hit1 | hit2 | hit3;

  always @(*) 
    begin
      if (hit0) hit_way = 2'd0;
      else if (hit1) hit_way = 2'd1;
      else if (hit2) hit_way = 2'd2;
      else if (hit3) hit_way = 2'd3;
      else hit_way = 2'd0;  // default
    end

  always @(*) 
    begin
      if (!valid[index*4+0]) lru_way = 2'd0;
      else if (!valid[index*4+1]) lru_way = 2'd1;
      else if (!valid[index*4+2]) lru_way = 2'd2;
      else if (!valid[index*4+3]) lru_way = 2'd3;
      else
      begin
        if (age[index*4+0] >= age[index*4+1] && age[index*4+0] >= age[index*4+2] && age[index*4+0] >= age[index*4+3]) lru_way = 2'd0;
        else if (age[index*4+1] >= age[index*4+0] && age[index*4+1] >= age[index*4+2] && age[index*4+1] >= age[index*4+3]) lru_way = 2'd1;
        else if (age[index*4+2] >= age[index*4+0] && age[index*4+2] >= age[index*4+1] && age[index*4+2] >= age[index*4+3]) lru_way = 2'd2;
        else lru_way = 2'd3;
      end
    end

  initial
    begin
      hit_way = 2'd0;
      valid_update = 1'd0;
      cache_tag_update = 10'd0;
      dirty_bit_update = 1'd0;

      cache_read = 1'd0; cache_write = 1'd0;
      mem_read = 1'd0; mem_write = 1'd0;
      evict_line = 1'd0; write_back = 1'd0;
      update_lru = 1'd0;
      finish = 1'd0;
      lru_way = 2'd0;

      st=3'd0;
      st_next=3'd0;
      operation=2'd0;
    end

  task clear_outputs;
    begin
      valid_update = 1'd0;
      cache_tag_update = 10'd0;
      dirty_bit_update = 1'd0;
      cache_read = 1'd0;
      cache_write = 1'd0;
      mem_read = 1'd0;
      mem_write = 1'd0;
      evict_line = 1'd0;
      write_back = 1'd0;
      update_lru = 1'd0;
      operation = OP_NONE; //nicio operatie
    end
  endtask

  always @(posedge clk) 
    begin
      case (st)
        IDLE: begin
          if (read_req)
            begin
              operation = OP_READ; //read 
              st_next = READ;
            end
          else if(write_req)
            begin
              operation = OP_WRITE; //write 
              st_next = WRITE;
            end
          else finish=0;
        end

        READ: begin
          if (hit)
            st_next = READ_HIT;
          else
            st_next = READ_MISS;
        end

        WRITE: begin
          if (hit)
            st_next = WRITE_HIT;
          else
            st_next = WRITE_MISS;
        end

        READ_HIT: begin
          cache_read = 1;
          update_lru = 1;
          st_next = FINISH;
        end

        WRITE_HIT: begin
          cache_write = 1;
          update_lru = 1;
          dirty_bit_update=1;
          st_next = FINISH;
        end

        READ_MISS: begin
          if(valid[index*4 + lru_way] && dirty_bits[index*4 + lru_way]) st_next = EVICT;
          else st_next = ALLOCATE;
        end

        WRITE_MISS: begin
          if(valid[index*4 + lru_way] && dirty_bits[index*4 + lru_way]) st_next = EVICT;
          else st_next = ALLOCATE;
        end

        EVICT: begin
          write_back = 1;
          mem_write = 1;
          evict_line = 1;
          st_next = ALLOCATE;
        end

        ALLOCATE: begin
          if (mem_ready)
            begin
              write_back = 0;
              mem_write = 0;
              evict_line = 0;
              valid_update = 1;
              cache_tag_update = tag;
              dirty_bit_update = operation[0]; 
              update_lru=1;
              mem_read=1;
              st_next = FINISH;
            end
        end

        FINISH: begin
          clear_outputs();
          finish = 1'd1;
          st_next = IDLE;
        end  
      endcase
    end


  always @(posedge clk or negedge rst_b)
    begin
      if (!rst_b)
        st <= IDLE;
      else
        st <= st_next;
    end
    
endmodule
