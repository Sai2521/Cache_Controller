`timescale 1ns / 1ps
`include "CacheController.v"
module Cache_Controller_tb;

  reg clk, rst_b;
  reg read_req, write_req;
  reg [23:0] address;         
  reg [511:0] valid;            
  reg [10:0] cache_tag [511:0];
  reg [511:0] dirty_bits;
  reg [1:0] age [511:0];
  reg mem_ready;

  wire [1:0]hit_way;
  wire valid_update; 
  wire [10:0] cache_tag_update;
  wire dirty_bit_update;

  wire cache_read, cache_write;
  wire mem_read,mem_write;
  wire evict_line, write_back;
  wire update_lru;
  wire finish;
  wire [1:0] lru_way;

  //am luat pentru ca exemplu adresa h'CA34F2, tag=1617, index=83, BO=12, WO=2 

  wire [10:0] cache_tag0 = cache_tag [83*4 + 0]; 
  wire [10:0] cache_tag1 = cache_tag [83*4 + 1]; 
  wire [10:0] cache_tag2 = cache_tag [83*4 + 2]; 
  wire [10:0] cache_tag3 = cache_tag [83*4 + 3];

  wire [1:0] age0 = age [83*4 + 0];
  wire [1:0] age1 = age [83*4 + 1];
  wire [1:0] age2 = age [83*4 + 2];  
  wire [1:0] age3 = age [83*4 + 3];

  wire valid0 = valid [83*4 + 0];
  wire valid1 = valid [83*4 + 1];
  wire valid2 = valid [83*4 + 2];  
  wire valid3 = valid [83*4 + 3];

  wire dirty_bit0 = dirty_bits [83*4 + 0];
  wire dirty_bit1 = dirty_bits [83*4 + 1];
  wire dirty_bit2 = dirty_bits [83*4 + 2];  
  wire dirty_bit3 = dirty_bits [83*4 + 3];

  Cache_Controller uut (
    .clk(clk),
    .rst_b(rst_b),
    .read_req(read_req),
    .write_req(write_req),
    .address(address),
    .valid(valid),
    .cache_tag(cache_tag),
    .dirty_bits(dirty_bits),
	  .age(age),
    .mem_ready(mem_ready),
    .hit_way(hit_way),
    .valid_update(valid_update),
    .cache_tag_update(cache_tag_update),
    .dirty_bit_update(dirty_bit_update),
    .cache_read(cache_read),
    .cache_write(cache_write),
    .mem_read(mem_read),
    .mem_write(mem_write),
    .evict_line(evict_line),
    .write_back(write_back),
    .update_lru(update_lru),
    .finish(finish),
    .lru_way(lru_way)
  );

  integer i;

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, Cache_Controller_tb);
    clk = 0;
    rst_b = 1;
    read_req = 0;
    write_req = 0;
    address = 24'hCA34F2; //tag=1617  index=83  BO=12  WO=2
    valid = 0;
    dirty_bits = 0;
    mem_ready = 0;
    for (i = 0; i < 512; i = i + 1) 
    begin
        cache_tag[i] = 0;
        age[i] = 0;
    end
  end

  //Scenario 1: Idle -> Read -> Read Hit -> FINISH -> Idle
  initial begin
	#10; rst_b=0; //#10;
	#10; rst_b=1; //#20;

  #10; 
  age[83*4 + 0] = 2'd2;
	age[83*4 + 1] = 2'd3;
	age[83*4 + 2] = 2'd0;
	age[83*4 + 3] = 2'd1;
  dirty_bits[83*4 + 0] = 1'b0;
  dirty_bits[83*4 + 1] = 1'b0;
  dirty_bits[83*4 + 2] = 1'b0;
  dirty_bits[83*4 + 3] = 1'b0;
	valid[83*4 + 0] = 1'b1;
	valid[83*4 + 1] = 1'b1;
	valid[83*4 + 2] = 1'b1;
	valid[83*4 + 3] = 1'b1;
  cache_tag[83*4 +0] = 11'd457; //in cache MISS
  cache_tag[83*4 +1] = 11'd25; //in cache MISS
  cache_tag[83*4 +2] = 11'd1617; //in cache HIT
	cache_tag[83*4 +3] = 11'd132; //in cache MISS #30

	#10; read_req=1; //#40;
	#100; read_req=0; //#140;
  end

  //Scenario 2: Idle -> Read -> Read Miss -> Allocate -> FINISH -> Idle
  initial begin
    #500;
    #10; rst_b=0; //#510;
	  #10; rst_b=1; //#520;
    
    #10; 
    age[83*4 + 0] = 2'd1;
    age[83*4 + 1] = 2'd0;
    age[83*4 + 2] = 2'd3;
    age[83*4 + 3] = 2'd2;
    dirty_bits[83*4 + 0] = 1'b0;
    dirty_bits[83*4 + 1] = 1'b0;
    dirty_bits[83*4 + 2] = 1'b0;
    dirty_bits[83*4 + 3] = 1'b0;
    valid[83*4 + 0] = 1'b1;
    valid[83*4 + 1] = 1'b1;
    valid[83*4 + 2] = 1'b1;
    valid[83*4 + 3] = 1'b1; 
    cache_tag[83*4 +0] = 11'd723; //in cache MISS
    cache_tag[83*4 +1] = 11'd125; //in cache MISS
    cache_tag[83*4 +2] = 11'd346; //in cache MISS
    cache_tag[83*4 +3] = 11'd69; //in cache MISS #530

    #10; read_req = 1; //#540
    #100; read_req = 0; //#640

    #390; mem_ready = 1;
    #100; mem_ready = 0;
  end

  //Scenario 3: Idle -> Read -> Read Miss -> Evict -> Allocate -> FINISH -> Idle
  initial begin
    #1400;
    #10; rst_b=0; //#1410;
	  #10; rst_b=1; //#1420;
    
    #10; 
    age[83*4 + 0] = 2'd1;
    age[83*4 + 1] = 2'd3;
    age[83*4 + 2] = 2'd2;
    age[83*4 + 3] = 2'd0;
    dirty_bits[83*4 + 0] = 1'b0;
    dirty_bits[83*4 + 1] = 1'b1;
    dirty_bits[83*4 + 2] = 1'b0;
    dirty_bits[83*4 + 3] = 1'b1;
    valid[83*4 + 0] = 1'b1;
    valid[83*4 + 1] = 1'b1;
    valid[83*4 + 2] = 1'b1;
    valid[83*4 + 3] = 1'b1; 
    cache_tag[83*4 +0] = 11'd829; //in cache MISS
    cache_tag[83*4 +1] = 11'd225; //in cache MISS
    cache_tag[83*4 +2] = 11'd23; //in cache MISS
    cache_tag[83*4 +3] = 11'd699; //in cache MISS #1430

    #10; read_req = 1; //#1440
    #100; read_req = 0; //#1540

    #390; mem_ready = 1;
    #100; mem_ready = 0;
  end

  //Scenario 4: Idle -> Write -> Write Hit -> FINISH -> Idle
  initial begin
    #2300;
    #10; rst_b=0; //#2310
    #10; rst_b=1; //#2320;

    #10; 
    age[83*4 + 0] = 2'd0;
    age[83*4 + 1] = 2'd3;
    age[83*4 + 2] = 2'd2;
    age[83*4 + 3] = 2'd1;
    dirty_bits[83*4 + 0] = 1'b0;
    dirty_bits[83*4 + 1] = 1'b0;
    dirty_bits[83*4 + 2] = 1'b0;
    dirty_bits[83*4 + 3] = 1'b0;
    valid[83*4 + 0] = 1'b1;
    valid[83*4 + 1] = 1'b1;
    valid[83*4 + 2] = 1'b1;
    valid[83*4 + 3] = 1'b0; //#30
    cache_tag[83*4 +0] = 11'd457; //in cache MISS
    cache_tag[83*4 +1] = 11'd25; //in cache MISS
    cache_tag[83*4 +2] = 11'd1617; //in cache HIT
    cache_tag[83*4 +3] = 11'd132; //in cache MISS #2330

    #10; write_req=1; //#2340;
    #100; write_req=0; //#2440;
  end

  //Scenario 5: Idle -> Write -> Write Miss -> Allocate -> FINISH -> Idle
  initial begin
    #2900;
    #10; rst_b=0; //#2910;
	  #10; rst_b=1; //#2920;
    
    #10; 
    age[83*4 + 0] = 2'd1;
    age[83*4 + 1] = 2'd0;
    age[83*4 + 2] = 2'd3;
    age[83*4 + 3] = 2'd2;
    dirty_bits[83*4 + 0] = 1'b0;
    dirty_bits[83*4 + 1] = 1'b0;
    dirty_bits[83*4 + 2] = 1'b0;
    dirty_bits[83*4 + 3] = 1'b0;
    valid[83*4 + 0] = 1'b1;
    valid[83*4 + 1] = 1'b1;
    valid[83*4 + 2] = 1'b1;
    valid[83*4 + 3] = 1'b1; 
    cache_tag[83*4 +0] = 11'd723; //in cache MISS
    cache_tag[83*4 +1] = 11'd125; //in cache MISS
    cache_tag[83*4 +2] = 11'd346; //in cache MISS
    cache_tag[83*4 +3] = 11'd69; //in cache MISS #2930

    #10; write_req = 1; //#2940
    #100; write_req = 0; //#3040

    #390; mem_ready = 1;
    #100; mem_ready = 0;
  end

  //Scenario 6: Idle -> Write -> Write Miss -> Evict -> Allocate -> FINISH -> Idle
  initial begin
    #3800;
    #10; rst_b=0; //#3810;
	  #10; rst_b=1; //#3820;
    
    #10; 
    age[83*4 + 0] = 2'd1;
    age[83*4 + 1] = 2'd3;
    age[83*4 + 2] = 2'd2;
    age[83*4 + 3] = 2'd0;
    dirty_bits[83*4 + 0] = 1'b0;
    dirty_bits[83*4 + 1] = 1'b1;
    dirty_bits[83*4 + 2] = 1'b0;
    dirty_bits[83*4 + 3] = 1'b1;
    valid[83*4 + 0] = 1'b1;
    valid[83*4 + 1] = 1'b1;
    valid[83*4 + 2] = 1'b1;
    valid[83*4 + 3] = 1'b1; 
    cache_tag[83*4 +0] = 11'd829; //in cache MISS
    cache_tag[83*4 +1] = 11'd225; //in cache MISS
    cache_tag[83*4 +2] = 11'd23; //in cache MISS
    cache_tag[83*4 +3] = 11'd699; //in cache MISS #3830

    #10; write_req = 1; //#3840
    #100; write_req = 0; //#3940

    #390; mem_ready = 1;
    #100; mem_ready = 0;
  end

  integer j;
  initial begin
    for(j=1;j<=500;j=j+1)
    begin
      #50; clk=~clk;
    end
    #50;
  end

endmodule


