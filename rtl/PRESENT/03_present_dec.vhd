library ieee;
use ieee.std_logic_1164.all;

entity present_dec is
        port (
                clk               : in std_logic;
                rst               : in std_logic;
                ena               : in std_logic;
                load_ena          : in std_logic;                
                ciphertext        : in std_logic_vector(63 downto 0);
                round_key         : in std_logic_vector(63 downto 0);
                plaintext         : out std_logic_vector(63 downto 0)
        );
end present_dec;

architecture structural of present_dec is
        constant BLOCK_SIZE : natural := 64;

        signal  mux_sel,
                plain_enable : std_logic;

        signal  state_reg_mux_out,
                state : std_logic_vector(BLOCK_SIZE - 1 downto 0);

        signal  inv_pbox_layer_input,
                inv_sbox_layer_input,
                inv_sbox_layer_out : std_logic_vector(BLOCK_SIZE - 1 downto 0);
begin
        -- Control signal for the multiplexer controlling the input of the State register
        -- When decrypting, the round counter is counting downwards starting from "11111".
        -- We need to fetch the round keys from the round keys memory, in a reversed order.
        -- Thus, when the decryption datapath is enabled and the counter has its initial value,
        -- we need to load the ciphertext into the State register.        
        mux_sel <= '1' when (load_ena = '1' and ena = '1') else '0';

        -- 64-bit mux which drives the state register
        state_reg_mux : entity work.mux
                generic map(
                        DATA_WIDTH => BLOCK_SIZE
                )
                port map(
                        input_A => inv_sbox_layer_out,
                        input_B => ciphertext,
                        sel     => mux_sel,
                        mux_out => state_reg_mux_out
                );

        -- 64-bit state register
        state_reg : entity work.reg
                generic map(
                        DATA_WIDTH => BLOCK_SIZE
                )
                port map(
                        clk  => clk,
                        rst  => rst,
                        ena  => ena,
                        din  => state_reg_mux_out,
                        dout => state
                );

        -- 64-bit xor to add current round key to state
        xor_64 : entity work.xor_n
                generic map(
                        DATA_WIDTH => BLOCK_SIZE
                )
                port map(
                        a => state,
                        b => round_key,
                        y => inv_pbox_layer_input
                );

        -- Inverse P-Box layer, the *diffusion* removal layer
        inv_pbox_layer : entity work.inv_pbox
                port map(
                        data_in  => inv_pbox_layer_input,
                        data_out => inv_sbox_layer_input
                );

        -- Inverse S-Box layer (16 inv S-Boxes in parallel), the *confusion* removal layer
        inv_sbox_layer : entity work.inv_sbox_layer
                port map(
                        inv_sbox_layer_in  => inv_sbox_layer_input,
                        inv_sbox_layer_out => inv_sbox_layer_out
                );
        
        plaintext <= inv_pbox_layer_input;
end structural;