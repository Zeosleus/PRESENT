library ieee;
use ieee.std_logic_1164.all;

entity mux_2 is
        port (
                input_A   : in std_logic;
                input_B   : in std_logic;
                sel       : in std_logic;
                mux_2_out : out std_logic
        );
end mux_2;

architecture behav of mux_2 is
begin
        process (input_A, input_B, sel) begin
                case sel is
                        when '0'    => mux_2_out    <= input_A;
                        when '1'    => mux_2_out    <= input_B;
                        when others => mux_2_out <= 'Z';
                end case;
        end process;
end behav;