module control_double
(
  input  wire        rst_n,
  input  wire        clk,
  input  wire        req,
  input  wire [15:0] sad,
  output wire        clr,
  output wire        en_addr_sw,
  output wire        en_addr_tb,
  output wire        en_paarray_sw,
  output reg         en_paarray_tb,
  output reg  [15:0] min_sad,
  output reg  [9:0]  min_mvec,
  output wire        ack
);

localparam TB_LENGTH = 8;
localparam SW_LENGTH = 32;

localparam INIT             = 2'b00;
localparam WAIT_REQ         = 2'b01;
localparam RUNNING          = 2'b10;
localparam WAIT_REQ_FALL    = 2'b11;
localparam WAIT_RUN         = 2'b01;
localparam ACTIVE           = 2'b10;
localparam DONE             = 2'b11;
localparam WAIT_DUMMY_CYCLE = 3'b100;
localparam WAIT_SRCH_END    = 2'b01;
localparam DONE_CNT         = 2'b10;
localparam DONE_ACTIVE      = 2'b11;

localparam CNT_ADDR_SW_END    = SW_LENGTH**2-2;
localparam CNT_ADDR_TB_END    = TB_LENGTH**2-1;
localparam CNT_PEARRAY_SW_END = SW_LENGTH**2+(SW_LENGTH-TB_LENGTH-1);
localparam CNT_DUMMY_CYCLE    = SW_LENGTH-TB_LENGTH+7;
localparam VEC_WIDTH          = $clog2(SW_LENGTH+1);

reg [1:0]  state_main;
reg [11:0] cnt_min;
reg [1:0]  state_addr_sw;
reg [12:0] cnt_addr_sw;
reg [1:0]  state_addr_tb;
reg [8:0]  cnt_addr_tb;
reg [1:0]  state_pearray_sw;
reg [12:0] cnt_pearray_sw;
reg [2:0]  state_valid;
reg [10:0] cnt_dummy;
reg [5:0]  cnt_x;
reg [5:0]  cnt_y;
reg [1:0]  state_done;
reg        cnt_done;

assign ack           = (state_main == WAIT_REQ_FALL);
assign clr           = (state_main == WAIT_REQ);
assign en_addr_sw    = (cnt_addr_sw != 0);
assign en_addr_tb    = (cnt_addr_tb != 0);
assign en_paarray_sw = (cnt_pearray_sw != 0);
wire   valid         = (cnt_x > (TB_LENGTH-2)) && (cnt_y > (TB_LENGTH-2));
wire   done          = (state_done == DONE_ACTIVE);

// FSM main
always @(posedge clk or negedge rst_n) begin
  if(~rst_n) begin
    state_main <= INIT;
  end else begin
    case(state_main)
      INIT          :          state_main <= WAIT_REQ;
      WAIT_REQ      : if( req) state_main <= RUNNING;
      RUNNING       : if(done) state_main <= WAIT_REQ_FALL;
      WAIT_REQ_FALL : if(~req) state_main <= WAIT_REQ;
      default       :          state_main <= 2'bxx;
    endcase
  end
end

// addr_sw
always @(posedge clk or negedge rst_n) begin
  if (~rst_n) begin
    state_addr_sw <= INIT;
    cnt_addr_sw   <= 0;
  end else begin
    case(state_addr_sw)
      INIT: begin
        state_addr_sw <= WAIT_RUN;
        cnt_addr_sw   <= 0;
      end
      WAIT_RUN:begin
        if(state_main==RUNNING)
          state_addr_sw <= ACTIVE;
        cnt_addr_sw <= 0;
      end
      ACTIVE:begin
        if(cnt_addr_sw==CNT_ADDR_SW_END)
          state_addr_sw <= DONE;
        cnt_addr_sw <= cnt_addr_sw + 1;
      end
      DONE:begin
        if(state_main==WAIT_REQ_FALL)
          state_addr_sw <= WAIT_RUN;
        cnt_addr_sw <= 0;
      end
      default:begin
        state_addr_sw <= 2'bxx;
        cnt_addr_sw   <= 12'dx;
      end
    endcase
  end
end

// addr_tb
always @(posedge clk or negedge rst_n) begin
  if (~rst_n) begin
    state_addr_tb <= INIT;
    cnt_addr_tb   <= 0;
  end else begin
    case(state_addr_tb)
      INIT:begin
        state_addr_tb <= WAIT_RUN;
        cnt_addr_tb   <= 0;
      end
      WAIT_RUN:begin
        if(state_main==RUNNING)
          state_addr_tb <= ACTIVE;
        cnt_addr_tb <= 0;
      end
      ACTIVE:begin
        if(cnt_addr_tb==CNT_ADDR_TB_END)
          state_addr_tb <= DONE;
        cnt_addr_tb <= cnt_addr_tb + 1;
      end
      DONE:begin
        if(state_main==WAIT_REQ_FALL)
          state_addr_tb <= WAIT_RUN;
        cnt_addr_tb <= 0;
      end
      default:begin
        state_addr_tb <= 2'bxx;
        cnt_addr_tb   <= 8'dx;
      end
    endcase
  end
end

// pearray_sw
always @(posedge clk or negedge rst_n) begin
  if (~rst_n) begin
    state_pearray_sw <= INIT;
    cnt_pearray_sw   <= 0;
  end else begin
    case(state_pearray_sw)
      INIT:begin
        state_pearray_sw <= WAIT_RUN;
        cnt_pearray_sw <= 0;
      end
      WAIT_RUN:begin
        if(state_addr_sw==ACTIVE)
          state_pearray_sw <= ACTIVE;
        cnt_pearray_sw <= 0;
      end
      ACTIVE:begin
        if(cnt_pearray_sw==CNT_PEARRAY_SW_END)
          state_pearray_sw <= DONE;
        cnt_pearray_sw <= cnt_pearray_sw + 1;
      end
      DONE:begin
        if(state_main==WAIT_REQ_FALL)
          state_pearray_sw <= WAIT_RUN;
        cnt_pearray_sw <= 0;
      end
      default:begin
        state_pearray_sw <= 2'bxx;
        cnt_pearray_sw   <= 12'dx;
      end
    endcase
  end
end

// pearray_tb
always @(posedge clk)
  en_paarray_tb <= en_addr_tb;

// valid
always @(posedge clk or negedge rst_n) begin
  if (~rst_n) begin
    state_valid <= INIT;
    cnt_dummy   <= 0;
    cnt_x       <= 0;
    cnt_y       <= 0;
  end else begin
    case(state_valid)
      {1'b0, INIT}:begin
        state_valid <= {1'b0, WAIT_RUN};
        cnt_dummy   <= 0;
      end
      {1'b0, WAIT_RUN}:begin
        if(state_main==RUNNING)
          state_valid <= WAIT_DUMMY_CYCLE;
        cnt_dummy <= 0;
      end
      WAIT_DUMMY_CYCLE:begin
        if(cnt_dummy==CNT_DUMMY_CYCLE)
          state_valid <= {1'b0, ACTIVE};
        cnt_dummy <= cnt_dummy + 1;
      end
      {1'b0, ACTIVE}:begin
        if((cnt_x==(SW_LENGTH-1))&&(cnt_y==(SW_LENGTH-1)))
          state_valid <= {1'b0, DONE};
        cnt_dummy <= 0;
        if(cnt_y < (SW_LENGTH-1))
          cnt_y <= cnt_y + 1;
        else begin
          cnt_y <= 0;
          cnt_x <= cnt_x + 1;
        end
      end
      {1'b0, DONE}:begin
        if(state_main==WAIT_REQ_FALL)
          state_valid <= {1'b0, WAIT_RUN};
        cnt_dummy <= 0;
        cnt_x     <= 0;
        cnt_y     <= 0;
      end
      default:begin
        state_valid <= 3'bxx;
        cnt_dummy   <= 11'dx;
        cnt_x       <= 6'dx;
        cnt_y       <= 6'dx;
      end
    endcase
  end
end

// done
always @(posedge clk or negedge rst_n) begin
  if (~rst_n)begin
    state_done <= INIT;
    cnt_done   <= 0;
  end else begin
    case (state_done)
      INIT:begin
        state_done <= WAIT_SRCH_END;
        cnt_done   <= 0;
      end
      WAIT_SRCH_END:begin
        if(cnt_x==SW_LENGTH)
          state_done <= DONE_CNT;
        cnt_done <= 0;
      end
      DONE_CNT:begin
        if(cnt_done==1'b1)
          state_done <= DONE_ACTIVE;
        cnt_done <= cnt_done + 1;
      end
      DONE_ACTIVE:begin
        state_done <= WAIT_SRCH_END;
        cnt_done   <= 0;
      end
      default:begin
        state_done <= 2'bxx;
        cnt_done   <= 1'bx;
      end
    endcase
  end
end

// min
always @(posedge clk or negedge rst_n) begin
  if(~rst_n) begin
    cnt_min  <= 0;
    min_sad  <= 16'hFFFF;
    min_mvec <= 0;
  end else begin
    case(state_main)
      INIT:begin
        cnt_min  <= 0;
        min_sad  <= 16'hFFFF;
        min_mvec <= 0;
      end
      WAIT_REQ:begin
        cnt_min  <= 0;
        min_sad  <= 16'hFFFF;
        min_mvec <= 0;
      end
      RUNNING:begin
        if(valid)begin
          cnt_min <= cnt_min + 1;
          if(min_sad > sad) begin
            min_sad  <= sad;
            min_mvec <= {cnt_y[4:0], cnt_x[4:0]};
          end
        end
      end
      WAIT_REQ_FALL : ;
      default:begin
        cnt_min  <= 12'dx;
        min_sad  <= 16'dx;
        min_mvec <= 12'dx;
      end
    endcase
  end
end

endmodule
