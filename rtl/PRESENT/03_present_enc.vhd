library ieee;
use ieee.std_logic_1164.all;

entity present_enc is
        port (
                clk               : in std_logic;
                rst               : in std_logic;
                ena               : in std_logic;
                out_ena           : in std_logic; -- output enable signal received from the Control Unit
                plaintext         : in std_logic_vector(63 downto 0);
                round_key         : in std_logic_vector(63 downto 0); -- read from round keys mem
                round_counter_val : in std_logic_vector(4 downto 0);
                ciphertext        : out std_logic_vector(63 downto 0)
        );
end present_enc;

architecture structural of present_enc is
        constant BLOCK_SIZE : natural := 64;

        signal  mux_sel,
                ciph_enable : std_logic;

        signal  state_reg_mux_out,
                state : std_logic_vector(BLOCK_SIZE - 1 downto 0);

        signal  sbox_layer_input,
                pbox_layer_input,
                pbox_layer_out : std_logic_vector(BLOCK_SIZE - 1 downto 0);        
begin
        -- Control signal for the multiplexer controlling the input of the State register
        -- When encrypting, the round counter is counting upwards starting from "00000".
        -- We need to fetch the round keys from the round keys memory.
        -- Thus, when the encryption datapath is enabled and the counter has its initial value,
        -- we need to load the plaintext into the State register.                
        mux_sel <= '1' when (round_counter_val = "00000" and ena = '1') else '0';
        
        -- 64-bit mux which drives the state register
        state_reg_mux : entity work.mux
                generic map(
                        DATA_WIDTH => BLOCK_SIZE
                )
                port map(
                        input_A => pbox_layer_out,
                        input_B => plaintext,
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
                        y => sbox_layer_input
                );

        -- S-Box layer (16 S-Boxes in parallel), the *confusion* layer
        sbox_layer : entity work.sbox_layer
                port map(
                        sbox_layer_in  => sbox_layer_input,
                        sbox_layer_out => pbox_layer_input
                );

        -- P-Box layer, the *diffusion* layer
        pbox_layer : entity work.pbox
                port map(
                        data_in  => pbox_layer_input,
                        data_out => pbox_layer_out
                );

        -- 64-bit ciphertext register
        ciph_reg : entity work.reg
                generic map(
                        DATA_WIDTH => BLOCK_SIZE
                )
                port map(
                        clk  => clk,
                        rst  => rst,
                        ena  => ciph_enable,
                        din  => sbox_layer_input,
                        dout => ciphertext
                );

        -- The ciphertext register enable signal, must be activated when the round counter overflows to "00000", which
        -- happens both at the first cycle of an encryption operation, but also after the end of an encryption operation.
        -- Therefore, we need an output enable signal (received from the Control Unit), in order to only write to the 
        -- shared, coprocessor-global data_out bus, when an encryption operation has finished.        
        ciph_enable <= '1' when (round_counter_val = "00000" and out_ena = '1') else '0';
end structural;