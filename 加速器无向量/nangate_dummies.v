// 修正版 Nangate45 行为模型（pin 名严格匹配库定义）

// Inverter / Buffer (输出 Z)
module INV_X1  (output Z, input A); assign Z = ~A; endmodule
module INV_X2  (output Z, input A); assign Z = ~A; endmodule
module INV_X4  (output Z, input A); assign Z = ~A; endmodule
module BUF_X1  (output Z, input A); assign Z =  A; endmodule
module BUF_X2  (output Z, input A); assign Z =  A; endmodule
module BUF_X4  (output Z, input A); assign Z =  A; endmodule

// NAND (输出 ZN = inverted)
module NAND2_X1 (output ZN, input A1, A2); assign ZN = ~(A1 & A2); endmodule
module NAND2_X2 (output ZN, input A1, A2); assign ZN = ~(A1 & A2); endmodule
module NAND3_X1 (output ZN, input A1, A2, A3); assign ZN = ~(A1 & A2 & A3); endmodule

// NOR (输出 ZN)
module NOR2_X1 (output ZN, input A1, A2); assign ZN = ~(A1 | A2); endmodule
module NOR2_X2 (output ZN, input A1, A2); assign ZN = ~(A1 | A2); endmodule

// XNOR (输出 Z)
module XNOR2_X1 (output Z, input A, B); assign Z = ~(A ^ B); endmodule
module XNOR2_X2 (output Z, input A, B); assign Z = ~(A ^ B); endmodule

// MUX (输出 Z)
module MUX2_X1 (output Z, input A, B, S); assign Z = S ? B : A; endmodule

// OAI21 (输出 ZN, 输入 A1 A2 B)
module OAI21_X1 (output ZN, input A1, A2, B); assign ZN = ~((A1 & A2) | B); endmodule
module OAI21_X2 (output ZN, input A1, A2, B); assign ZN = ~((A1 & A2) | B); endmodule

// AOI21 (输出 ZN, 输入 A1 A2 B)
module AOI21_X1 (output ZN, input A1, A2, B); assign ZN = ~((A1 & A2) | B); endmodule

// 额外常见 cell（预防后续报错）
module AND2_X1 (output Z, input A1, A2); assign Z = A1 & A2; endmodule
module OR2_X1  (output Z, input A1, A2); assign Z = A1 | A2; endmodule
