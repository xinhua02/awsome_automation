// Gray code converter (binary -> gray)
module gray_converter #(
  parameter WIDTH = 4
) (
  input  logic [WIDTH-1:0] binary,
  output logic [WIDTH-1:0] gray
);
  assign gray = binary ^ (binary >> 1);
endmodule
