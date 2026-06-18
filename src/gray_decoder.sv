// Gray code decoder (gray -> binary)
module gray_decoder #(
  parameter WIDTH = 4
) (
  input  logic [WIDTH-1:0] gray,
  output logic [WIDTH-1:0] binary
);
  logic [WIDTH-1:0] temp;
  
  always_comb begin
    temp[WIDTH-1] = gray[WIDTH-1];
    for (int i = WIDTH-2; i >= 0; i--) begin
      temp[i] = temp[i+1] ^ gray[i];
    end
    binary = temp;
  end
endmodule
