library ieee;
use ieee.std_logic_1164.all;

entity pbox is
        port (
                pbox_in  : in std_logic_vector(63 downto 0);
                pbox_out : out std_logic_vector(63 downto 0)
        );
end pbox;

architecture behavioral of pbox is
begin
        permutate_loop : for i in 0 to 62 generate
                pbox_out((i * 16) mod 63) <= pbox_in(i);
        end generate permutate_loop;
        pbox_out(63) <= pbox_in(63);
end behavioral;