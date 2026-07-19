-- changes for seperate audio outputs and enable now enables cpu access as well
--
-- A simulation model of YM2149 (AY-3-8910 with bells on)

-- Copyright (c) MikeJ - Jan 2005
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS CODE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- You are responsible for any legal issues arising from your use of this code.
--
-- The latest version of this file can be found at: www.fpgaarcade.com
--
-- Email support@fpgaarcade.com
--
-- Revision list
--
-- version 001 initial release
--
-- Clues from MAME sound driver and Kazuhiro TSUJIKAWA
--
-- These are the measured outputs from a real chip for a single Isolated channel into a 1K load (V)
-- vol 15 .. 0
-- 3.27 2.995 2.741 2.588 2.452 2.372 2.301 2.258 2.220 2.198 2.178 2.166 2.155 2.148 2.141 2.132
-- As the envelope volume is 5 bit, I have fitted a curve to the not quite log shape in order
-- to produced all the required values.
-- (The first part of the curve is a bit steeper and the last bit is more linear than expected)
--
-- NOTE, when MIXER_VOLTABLE = '0', this component uses LINEAR mixing of the three analogue channels, 
-- and is only accurate for designs where the outputs are buffered and not simply wired together.
-- The ouput level is more complex in that case and requires a larger table (MIXER_VOLTABLE = '1').

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

entity YM2149 is
  generic (
    MIXER_VOLTABLE      : std_logic := '0';
    IO_OUT_READ_IN      : std_logic := '1'
  );
  port (
  -- data bus
  I_DA                : in  std_logic_vector(7 downto 0);
  O_DA                : out std_logic_vector(7 downto 0);
  O_DA_OE_L           : out std_logic;
  -- control
  I_A9_L              : in  std_logic := '0';
  I_A8                : in  std_logic := '1';
  I_BDIR              : in  std_logic;
  I_BC2               : in  std_logic := '1';
  I_BC1               : in  std_logic;
  I_SEL_L             : in  std_logic := '1';

  I_STEREO            : in  std_logic := '0';

  -- separate channel output
  O_AUDIO             : out std_logic_vector(7 downto 0);
  O_CHAN              : out std_logic_vector(1 downto 0);

  -- mixed output
  O_AUDIO_L           : out std_logic_vector(9 downto 0);
  O_AUDIO_R           : out std_logic_vector(9 downto 0);

  -- port a
  I_IOA               : in  std_logic_vector(7 downto 0);
  O_IOA               : out std_logic_vector(7 downto 0);
  O_IOA_OE_L          : out std_logic;
  -- port b
  I_IOB               : in  std_logic_vector(7 downto 0);
  O_IOB               : out std_logic_vector(7 downto 0);
  O_IOB_OE_L          : out std_logic;

  ENA                 : in  std_logic; -- clock enable for higher speed operation
  RESET_L             : in  std_logic;
  CLK                 : in  std_logic
  );
end;

architecture RTL of YM2149 is
  type  array_16x8   is array (0 to 15) of std_logic_vector( 7 downto 0);
  type  array_3x12   is array (1 to  3) of std_logic_vector(11 downto 0);

  signal cnt_div              : std_logic_vector(3 downto 0) := (others => '0');
  signal cnt_div_t1           : std_logic_vector(3 downto 0);
  signal noise_div            : std_logic := '0';
  signal ena_div              : std_logic;
  signal ena_div_noise        : std_logic;
  signal poly17               : std_logic_vector(16 downto 0) := (others => '0');

  -- registers
  signal addr                 : std_logic_vector(7 downto 0);
  signal busctrl_addr         : std_logic;
  signal busctrl_we           : std_logic;
  signal busctrl_re           : std_logic;

  signal reg                  : array_16x8;
  signal env_reset            : std_logic;
  signal ioa_inreg            : std_logic_vector(7 downto 0);
  signal iob_inreg            : std_logic_vector(7 downto 0);

  signal noise_gen_cnt        : std_logic_vector(4 downto 0);
  signal noise_gen_op         : std_logic;
  signal tone_gen_cnt         : array_3x12 := (others => (others => '0'));
  signal tone_gen_op          : std_logic_vector(3 downto 1) := "000";

  signal env_gen_cnt          : std_logic_vector(15 downto 0);
  signal env_ena              : std_logic;
  signal env_hold             : std_logic;
  signal env_inc              : std_logic;
  signal env_vol              : std_logic_vector(4 downto 0);

  signal tone_ena_l           : std_logic;
  signal tone_src             : std_logic;
  signal noise_ena_l          : std_logic;
  signal chan_vol             : std_logic_vector(4 downto 0);

  signal dac_amp              : std_logic_vector(7 downto 0);

  signal vol_l                : std_logic_vector(9 downto 0);
  signal vol_r                : std_logic_vector(9 downto 0);
  signal vol_mixer_l          : std_logic_vector(9 downto 0);
  signal vol_mixer_r          : std_logic_vector(9 downto 0);

  signal vol_table_in_l       : std_logic_vector(11 downto 0);
  signal vol_table_in_r       : std_logic_vector(11 downto 0);
  signal vol_table_out_l      : std_logic_vector(9 downto 0);
  signal vol_table_out_r      : std_logic_vector(9 downto 0);

begin
  -- cpu i/f
  p_busdecode            : process(I_BDIR, I_BC2, I_BC1, addr, I_A9_L, I_A8)
    variable cs : std_logic;
    variable sel : std_logic_vector(2 downto 0);
  begin
    -- BDIR BC2 BC1 MODE
    --   0   0   0  inactive
    --   0   0   1  address
    --   0   1   0  inactive
    --   0   1   1  read
    --   1   0   0  address
    --   1   0   1  inactive
    --   1   1   0  write
    --   1   1   1  read
    busctrl_addr <= '0';
    busctrl_we <= '0';
    busctrl_re <= '0';

    cs := '0';
    if (I_A9_L = '0') and (I_A8 = '1') and (addr(7 downto 4) = "0000") then
      cs := '1';
    end if;

    sel := (I_BDIR & I_BC2 & I_BC1);
    case sel is
      when "000" => null;
      when "001" => busctrl_addr <= '1';
      when "010" => null;
      when "011" => busctrl_re   <= cs;
      when "100" => busctrl_addr <= '1';
      when "101" => null;
      when "110" => busctrl_we   <= cs;
      when "111" => busctrl_addr <= '1';
      when others => null;
    end case;
  end process;

  p_oe                   : process(busctrl_re)
  begin
    -- if we are emulating a real chip, maybe clock this to fake up the tristate typ delay of 100ns
    O_DA_OE_L <= not (busctrl_re);
  end process;

  --
  -- CLOCKED
  --
  p_waddr                : process(RESET_L, CLK)
  begin
    -- looks like registers are latches in real chip, but the address is caught at the end of the address state.
    if (RESET_L = '0') then
      addr <= (others => '0');
    elsif rising_edge(CLK) then
      if (busctrl_addr = '1') then
        addr <= I_DA;
      end if;
    end if;
  end process;

  p_wdata                : process(RESET_L, CLK)
  begin
    if (RESET_L = '0') then
      reg <= (others => (others => '0'));
      env_reset <= '1';
    elsif rising_edge(CLK) then
      env_reset <= '0';
      if (busctrl_we = '1') then
        reg(to_integer(unsigned(addr(3 downto 0)))) <= I_DA;
        if addr(3 downto 0) = x"D" then
          env_reset <= '1';
        end if;
      end if;
    end if;
  end process;

  p_rdata                : process(busctrl_re, addr, reg, ioa_inreg, iob_inreg)
  begin
    O_DA <= (others => '0'); -- 'X'
    if (busctrl_re = '1') then -- not necessary, but useful for putting 'X's in the simulator
      case addr(3 downto 0) is
        when x"0" => O_DA <= reg(0) ;
        when x"1" => O_DA <= "0000" & reg(1)(3 downto 0) ;
        when x"2" => O_DA <= reg(2) ;
        when x"3" => O_DA <= "0000" & reg(3)(3 downto 0) ;
        when x"4" => O_DA <= reg(4) ;
        when x"5" => O_DA <= "0000" & reg(5)(3 downto 0) ;
        when x"6" => O_DA <= "000"  & reg(6)(4 downto 0) ;
        when x"7" => O_DA <= reg(7) ;
        when x"8" => O_DA <= "000"  & reg(8)(4 downto 0) ;
        when x"9" => O_DA <= "000"  & reg(9)(4 downto 0) ;
        when x"A" => O_DA <= "000"  & reg(10)(4 downto 0) ;
        when x"B" => O_DA <= reg(11);
        when x"C" => O_DA <= reg(12);
        when x"D" => O_DA <= "0000" & reg(13)(3 downto 0);
        when x"E" => if reg(7)(6) = '0' or IO_OUT_READ_IN = '1' then -- input
                       O_DA <= ioa_inreg;
                     else
                       O_DA <= reg(14); -- read output reg
                     end if;
        when x"F" => if Reg(7)(7) = '0' or IO_OUT_READ_IN = '1' then
                       O_DA <= iob_inreg;
                     else
                       O_DA <= reg(15);
                     end if;
        when others => null;
      end case;
    end if;
  end process;
  --
  p_divider              : process
  begin
    wait until rising_edge(CLK);
    -- / 8 when SEL is high and /16 when SEL is low
    if (ENA = '1') then
      ena_div <= '0';
      ena_div_noise <= '0';
      if (cnt_div = "0000") then
        cnt_div <= (not I_SEL_L) & "111";
        ena_div <= '1';

        noise_div <= not noise_div;
        if (noise_div = '1') then
          ena_div_noise <= '1';
        end if;
      else
        cnt_div <= cnt_div - "1";
      end if;
    end if;
  end process;

  p_noise_gen            : process
    variable noise_gen_comp : std_logic_vector(4 downto 0);
    variable poly17_zero : std_logic;
  begin
    wait until rising_edge(CLK);
    if (reg(6)(4 downto 0) = "00000") then
      noise_gen_comp := "00000";
    else
      noise_gen_comp := (reg(6)(4 downto 0) - "1");
    end if;

    poly17_zero := '0';
    if (poly17 = "00000000000000000") then poly17_zero := '1'; end if;

    if (ENA = '1') then
      if (ena_div_noise = '1') then -- divider ena

        if (noise_gen_cnt >= noise_gen_comp) then
          noise_gen_cnt <= "00000";
          poly17 <= (poly17(0) xor poly17(2) xor poly17_zero) & poly17(16 downto 1);
        else
          noise_gen_cnt <= (noise_gen_cnt + "1");
        end if;
      end if;
    end if;
  end process;
  noise_gen_op <= poly17(0);

  p_tone_gens            : process
    variable tone_gen_freq : array_3x12;
    variable tone_gen_comp : array_3x12;
  begin
    wait until rising_edge(CLK);
    -- looks like real chips count up - we need to get the Exact behaviour ..
    tone_gen_freq(1) := reg(1)(3 downto 0) & reg(0);
    tone_gen_freq(2) := reg(3)(3 downto 0) & reg(2);
    tone_gen_freq(3) := reg(5)(3 downto 0) & reg(4);
    -- period 0 = period 1
    for i in 1 to 3 loop
      if (tone_gen_freq(i) = x"000") then
        tone_gen_comp(i) := x"000";
      else
        tone_gen_comp(i) := (tone_gen_freq(i) - "1");
      end if;
    end loop;

    if (ENA = '1') then
      for i in 1 to 3 loop
        if (ena_div = '1') then -- divider ena

          if (tone_gen_cnt(i) >= tone_gen_comp(i)) then
            tone_gen_cnt(i) <= x"000";
            tone_gen_op(i) <= not tone_gen_op(i);
          else
            tone_gen_cnt(i) <= (tone_gen_cnt(i) + "1");
          end if;
        end if;
      end loop;
    end if;
  end process;

  p_envelope_freq        : process
    variable env_gen_freq : std_logic_vector(15 downto 0);
    variable env_gen_comp : std_logic_vector(15 downto 0);
  begin
    wait until rising_edge(CLK);
    env_gen_freq := reg(12) & reg(11);
    -- envelope freqs 1 and 0 are the same.
    if (env_gen_freq = x"0000") then
      env_gen_comp := x"0000";
    else
      env_gen_comp := (env_gen_freq - "1");
    end if;

    if (ENA = '1') then
      env_ena <= '0';
      if (ena_div = '1') then -- divider ena
        if (env_gen_cnt >= env_gen_comp) then
          env_gen_cnt <= x"0000";
          env_ena <= '1';
        else
          env_gen_cnt <= (env_gen_cnt + "1");
        end if;
      end if;
    end if;
  end process;

  p_envelope_shape       : process(env_reset, reg, CLK)
    variable is_bot    : boolean;
    variable is_bot_p1 : boolean;
    variable is_top_m1 : boolean;
    variable is_top    : boolean;
  begin
        -- envelope shapes
        -- C AtAlH
        -- 0 0 x x  \___
        --
        -- 0 1 x x  /___
        --
        -- 1 0 0 0  \\\\
        --
        -- 1 0 0 1  \___
        --
        -- 1 0 1 0  \/\/
        --           ___
        -- 1 0 1 1  \
        --
        -- 1 1 0 0  ////
        --           ___
        -- 1 1 0 1  /
        --
        -- 1 1 1 0  /\/\
        --
        -- 1 1 1 1  /___
    if rising_edge(CLK) then
      if (env_reset = '1') then
        -- load initial state
        if (reg(13)(2) = '0') then -- attack
          env_vol <= "11111";
          env_inc <= '0'; -- -1
        else
          env_vol <= "00000";
          env_inc <= '1'; -- +1
        end if;
        env_hold <= '0';

      else
        is_bot    := (env_vol = "00000");
        is_bot_p1 := (env_vol = "00001");
        is_top_m1 := (env_vol = "11110");
        is_top    := (env_vol = "11111");

        if (ENA = '1' and env_ena = '1') then
          if (env_hold = '0') then
            if (env_inc = '1') then
              env_vol <= (env_vol + "00001");
            else
              env_vol <= (env_vol + "11111");
            end if;
          end if;

          -- envelope shape control.
          if (reg(13)(3) = '0') then
            if (env_inc = '0') then -- down
              if is_bot_p1 then env_hold <= '1'; end if;
            else
              if is_top then env_hold <= '1'; end if;
            end if;
          else
            if (reg(13)(0) = '1') then -- hold = 1
              if (env_inc = '0') then -- down
                if (reg(13)(1) = '1') then -- alt
                  if is_bot    then env_hold <= '1'; end if;
                else
                  if is_bot_p1 then env_hold <= '1'; end if;
                end if;
              else
                if (reg(13)(1) = '1') then -- alt
                  if is_top    then env_hold <= '1'; end if;
                else
                  if is_top_m1 then env_hold <= '1'; end if;
                end if;
              end if;

            elsif (reg(13)(1) = '1') then -- alternate
              if (env_inc = '0') then -- down
                if is_bot_p1 then env_hold <= '1'; end if;
                if is_bot    then env_hold <= '0'; env_inc <= '1'; end if;
              else
                if is_top_m1 then env_hold <= '1'; end if;
                if is_top    then env_hold <= '0'; env_inc <= '0'; end if;
              end if;
            end if;

          end if;
        end if;
      end if;
    end if;
  end process;

-- output mixer

  p_chan_mixer           : process(cnt_div, reg, tone_gen_op)
  begin
    tone_ena_l  <= '1'; tone_src <= '1';
    noise_ena_l <= '1'; chan_vol <= "00000";
    case cnt_div(1 downto 0) is
      when "00" =>
        tone_ena_l  <= reg(7)(0); tone_src <= tone_gen_op(1); chan_vol <= reg(8)(4 downto 0);
        noise_ena_l <= reg(7)(3);
      when "01" =>
        tone_ena_l  <= reg(7)(1); tone_src <= tone_gen_op(2); chan_vol <= reg(9)(4 downto 0);
        noise_ena_l <= reg(7)(4);
      when "10" =>
        tone_ena_l  <= reg(7)(2); tone_src <= tone_gen_op(3); chan_vol <= reg(10)(4 downto 0);
        noise_ena_l <= reg(7)(5);
      when "11" => null; -- tone gen outputs become valid on this clock
      when others => null;
    end case;
  end process;

  p_op_mixer             : process
    variable chan_mixed : std_logic;
    variable chan_amp : std_logic_vector(4 downto 0);
  begin
    wait until rising_edge(CLK);
    if (ENA = '1') then

      chan_mixed := (tone_ena_l or tone_src) and (noise_ena_l or noise_gen_op);

      chan_amp := (others => '0');
      if (chan_mixed = '1') then
        if (chan_vol(4) = '0') then
          if (chan_vol(3 downto 0) = "0000") then -- nothing is easy ! make sure quiet is quiet
            chan_amp := "00000";
          else
            chan_amp := chan_vol(3 downto 0) & '1'; -- make sure level 31 (env) = level 15 (tone)
          end if;
        else
          chan_amp := env_vol(4 downto 0);
        end if;
      end if;

      dac_amp <= x"00";
      case chan_amp is
        when "11111" => dac_amp <= x"FF";
        when "11110" => dac_amp <= x"D9";
        when "11101" => dac_amp <= x"BA";
        when "11100" => dac_amp <= x"9F";
        when "11011" => dac_amp <= x"88";
        when "11010" => dac_amp <= x"74";
        when "11001" => dac_amp <= x"63";
        when "11000" => dac_amp <= x"54";
        when "10111" => dac_amp <= x"48";
        when "10110" => dac_amp <= x"3D";
        when "10101" => dac_amp <= x"34";
        when "10100" => dac_amp <= x"2C";
        when "10011" => dac_amp <= x"25";
        when "10010" => dac_amp <= x"1F";
        when "10001" => dac_amp <= x"1A";
        when "10000" => dac_amp <= x"16";
        when "01111" => dac_amp <= x"13";
        when "01110" => dac_amp <= x"10";
        when "01101" => dac_amp <= x"0D";
        when "01100" => dac_amp <= x"0B";
        when "01011" => dac_amp <= x"09";
        when "01010" => dac_amp <= x"08";
        when "01001" => dac_amp <= x"07";
        when "01000" => dac_amp <= x"06";
        when "00111" => dac_amp <= x"05";
        when "00110" => dac_amp <= x"04";
        when "00101" => dac_amp <= x"03";
        when "00100" => dac_amp <= x"03";
        when "00011" => dac_amp <= x"02";
        when "00010" => dac_amp <= x"02";
        when "00001" => dac_amp <= x"01";
        when "00000" => dac_amp <= x"00";
        when others => null;
      end case;

      cnt_div_t1 <= cnt_div;
    end if;
  end process;

  p_audio_output         : process(RESET_L, CLK)
  begin
    if (RESET_L = '0') then
      O_AUDIO <= (others => '0');
      O_CHAN  <= (others => '0');
    elsif rising_edge(CLK) then

      if (ENA = '1') then
        O_AUDIO <= dac_amp(7 downto 0);
        O_CHAN  <= cnt_div_t1(1 downto 0);
      end if;

    end if;
  end process;

  -- output mixer(s)

  p_chan_mixer_linear     : process(RESET_L, CLK)
  begin
    if (RESET_L = '0') then
      vol_l <= (others => '0');
      vol_r <= (others => '0');
      vol_mixer_l  <= (others => '0');
      vol_mixer_r  <= (others => '0');
    elsif rising_edge(CLK) then

      if (ENA = '1') then
        case cnt_div_t1(1 downto 0) is
        when "10" => -- Channel C
          vol_r <= "00" & dac_amp;
          if I_STEREO = '0' then
            vol_l <= "00" & dac_amp;
          else
            vol_l <= (others => '0');
          end if;
        when "01" => -- Channel B
          vol_l <= vol_l + dac_amp;
          vol_r <= vol_r + dac_amp;
        when "00" => -- Channel A
          if I_STEREO = '0' then
            vol_r <= vol_r + dac_amp;
          end if;
          vol_l <= vol_l + dac_amp;
        when "11" =>
          vol_mixer_l <= vol_l;
          vol_mixer_r <= vol_r;
        when others => null;
        end case;
      end if;
    end if;
  end process;

  VOLTABLE: if MIXER_VOLTABLE = '1' generate

  p_chan_mixer_table     : process
    variable chan_mixed : std_logic_vector(2 downto 0);
  begin
    wait until rising_edge(CLK);
    if (ENA = '1') then
      chan_mixed(0) := (reg(7)(0) or tone_gen_op(1)) and (reg(7)(3) or noise_gen_op);
      chan_mixed(1) := (reg(7)(1) or tone_gen_op(2)) and (reg(7)(4) or noise_gen_op);
      chan_mixed(2) := (reg(7)(2) or tone_gen_op(3)) and (reg(7)(5) or noise_gen_op);

      vol_table_in_l <= x"000";
      vol_table_in_r <= x"000";

      if (chan_mixed(0) = '1') then
        if(I_STEREO = '1') then
          if (reg(8)(4) = '0') then
            vol_table_in_l(3 downto 0) <= reg(8)(3 downto 0);
          else
            vol_table_in_l(3 downto 0) <= env_vol(4 downto 1);
          end if;
        else
          if (reg(8)(4) = '0') then
            vol_table_in_l(3 downto 0) <= reg(8)(3 downto 0);
            vol_table_in_r(3 downto 0) <= reg(8)(3 downto 0);
          else
            vol_table_in_l(3 downto 0) <= env_vol(4 downto 1);
            vol_table_in_r(3 downto 0) <= env_vol(4 downto 1);
          end if;
        end if;
      end if;

      if (chan_mixed(1) = '1') then
        if (reg(9)(4) = '0') then
          vol_table_in_l(7 downto 4) <= reg(9)(3 downto 0);
          vol_table_in_r(7 downto 4) <= reg(9)(3 downto 0);
        else
          vol_table_in_l(7 downto 4) <= env_vol(4 downto 1);
          vol_table_in_r(7 downto 4) <= env_vol(4 downto 1);
        end if;
      end if;

      if (chan_mixed(2) = '1') then
        if(I_STEREO = '1') then
          if (reg(10)(4) = '0') then
            vol_table_in_r(11 downto 8) <= reg(10)(3 downto 0);
          else
            vol_table_in_r(11 downto 8) <= env_vol(4 downto 1);
          end if;
        else
          if (reg(10)(4) = '0') then
            vol_table_in_l(11 downto 8) <= reg(10)(3 downto 0);
            vol_table_in_r(11 downto 8) <= reg(10)(3 downto 0);
          else
            vol_table_in_l(11 downto 8) <= env_vol(4 downto 1);
            vol_table_in_r(11 downto 8) <= env_vol(4 downto 1);
          end if;
        end if;
      end if;
    end if;
  end process;

  u_vol_table : work.vol_table
    port map (
      CLK         => clk,
      ADDR_A      => vol_table_in_l,
      DATA_A      => vol_table_out_l,
      ADDR_B      => vol_table_in_r,
      DATA_B      => vol_table_out_r
      );
  end generate; -- VOLTABLE

  NO_VOLTABLE: if MIXER_VOLTABLE = '0' generate
    vol_table_out_l <= (others => '0');
    vol_table_out_r <= (others => '0');
  end generate;

  -- mixed audio output

  p_vol_out                : process
    variable chan_mixed : std_logic;
    variable chan_amp : std_logic_vector(4 downto 0);
  begin
    wait until rising_edge(CLK);

    if (RESET_L = '0') then
      O_AUDIO_L <= (others => '0');
      O_AUDIO_R <= (others => '0');
    else
      if (MIXER_VOLTABLE = '1') then
        O_AUDIO_L <= vol_table_out_l;
        O_AUDIO_R <= vol_table_out_r;
      else
        O_AUDIO_L <= vol_mixer_l;
        O_AUDIO_R <= vol_mixer_r;
      end if;
    end if;
  end process;

  -- IO ports

  p_io_ports             : process(reg)
  begin
    O_IOA      <= reg(14);
    O_IOA_OE_L <= not reg(7)(6);
    O_IOB      <= reg(15);
    O_IOB_OE_L <= not reg(7)(7);
  end process;

  p_io_ports_inreg       : process
  begin
    wait until rising_edge(CLK);
    ioa_inreg <= I_IOA;
    iob_inreg <= I_IOB;
  end process;
end architecture RTL;


-- Sixteen level by Three voice YM2149 volume_table[C][B][A]
-- Data measured by Paulo Simoes. Copyright 2012 Paulo Simoes.
-- original 16 bit data reduced to 10 bit

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vol_table is
  port (
    CLK         : in    std_logic;
    ADDR_A      : in    std_logic_vector(11 downto 0);
    DATA_A      : out   std_logic_vector(9 downto 0);
    ADDR_B      : in    std_logic_vector(11 downto 0);
    DATA_B      : out   std_logic_vector(9 downto 0)
    );
end;

architecture RTL of vol_table is


  type ROM_ARRAY is array(0 to 4095) of std_logic_vector(9 downto 0);
  constant voltable : ROM_ARRAY := (
	"00"&x"00","00"&x"01","00"&x"03","00"&x"06","00"&x"09","00"&x"0d","00"&x"13","00"&x"1a","00"&x"27","00"&x"36","00"&x"50","00"&x"6e","00"&x"a1","00"&x"e4","01"&x"66","10"&x"1a",
	"00"&x"01","00"&x"04","00"&x"06","00"&x"08","00"&x"0c","00"&x"0f","00"&x"16","00"&x"1d","00"&x"2a","00"&x"38","00"&x"52","00"&x"70","00"&x"a4","00"&x"e6","01"&x"67","10"&x"1a",
	"00"&x"03","00"&x"06","00"&x"08","00"&x"0a","00"&x"0e","00"&x"11","00"&x"18","00"&x"1f","00"&x"2c","00"&x"3a","00"&x"54","00"&x"72","00"&x"a5","00"&x"e8","01"&x"68","10"&x"1a",
	"00"&x"06","00"&x"08","00"&x"0a","00"&x"0c","00"&x"10","00"&x"14","00"&x"1a","00"&x"21","00"&x"2e","00"&x"3d","00"&x"56","00"&x"74","00"&x"a7","00"&x"e9","01"&x"69","10"&x"1b",
	"00"&x"09","00"&x"0c","00"&x"0e","00"&x"10","00"&x"13","00"&x"17","00"&x"1e","00"&x"25","00"&x"31","00"&x"40","00"&x"5a","00"&x"77","00"&x"aa","00"&x"ec","01"&x"6b","10"&x"1b",
	"00"&x"0d","00"&x"0f","00"&x"11","00"&x"14","00"&x"17","00"&x"1b","00"&x"21","00"&x"29","00"&x"35","00"&x"43","00"&x"5d","00"&x"7a","00"&x"ad","00"&x"ef","01"&x"6d","10"&x"1c",
	"00"&x"13","00"&x"16","00"&x"18","00"&x"1a","00"&x"1e","00"&x"21","00"&x"28","00"&x"2f","00"&x"3b","00"&x"4a","00"&x"63","00"&x"80","00"&x"b3","00"&x"f4","01"&x"71","10"&x"1d",
	"00"&x"1a","00"&x"1d","00"&x"1f","00"&x"21","00"&x"25","00"&x"29","00"&x"2f","00"&x"36","00"&x"42","00"&x"50","00"&x"6a","00"&x"85","00"&x"b9","00"&x"f9","01"&x"75","10"&x"1f",
	"00"&x"27","00"&x"2a","00"&x"2c","00"&x"2e","00"&x"31","00"&x"35","00"&x"3b","00"&x"42","00"&x"4e","00"&x"5c","00"&x"75","00"&x"90","00"&x"c3","01"&x"03","01"&x"7d","10"&x"22",
	"00"&x"36","00"&x"38","00"&x"3a","00"&x"3d","00"&x"40","00"&x"43","00"&x"4a","00"&x"50","00"&x"5c","00"&x"6a","00"&x"82","00"&x"9d","00"&x"d0","01"&x"0e","01"&x"87","10"&x"28",
	"00"&x"50","00"&x"52","00"&x"54","00"&x"56","00"&x"5a","00"&x"5d","00"&x"63","00"&x"6a","00"&x"75","00"&x"82","00"&x"98","00"&x"b4","00"&x"e6","01"&x"22","01"&x"99","10"&x"34",
	"00"&x"6e","00"&x"70","00"&x"72","00"&x"74","00"&x"77","00"&x"7a","00"&x"80","00"&x"85","00"&x"90","00"&x"9d","00"&x"b4","00"&x"cf","01"&x"01","01"&x"3b","01"&x"af","10"&x"44",
	"00"&x"a1","00"&x"a4","00"&x"a5","00"&x"a7","00"&x"aa","00"&x"ad","00"&x"b3","00"&x"b9","00"&x"c3","00"&x"d0","00"&x"e6","01"&x"01","01"&x"2f","01"&x"6a","01"&x"dc","10"&x"69",
	"00"&x"e4","00"&x"e6","00"&x"e8","00"&x"e9","00"&x"ec","00"&x"ef","00"&x"f4","00"&x"f9","01"&x"03","01"&x"0e","01"&x"22","01"&x"3b","01"&x"6a","01"&x"a3","10"&x"14","10"&x"9a",
	"01"&x"66","01"&x"67","01"&x"68","01"&x"69","01"&x"6b","01"&x"6d","01"&x"71","01"&x"75","01"&x"7d","01"&x"87","01"&x"99","01"&x"af","01"&x"dc","10"&x"14","10"&x"79","10"&x"f3",
	"10"&x"1a","10"&x"1a","10"&x"1a","10"&x"1b","10"&x"1b","10"&x"1c","10"&x"1d","10"&x"1f","10"&x"22","10"&x"28","10"&x"34","10"&x"44","10"&x"69","10"&x"9a","10"&x"f3","11"&x"61",
	"00"&x"01","00"&x"04","00"&x"06","00"&x"08","00"&x"0c","00"&x"0f","00"&x"16","00"&x"1d","00"&x"2a","00"&x"38","00"&x"52","00"&x"70","00"&x"a4","00"&x"e6","01"&x"67","10"&x"1a",
	"00"&x"04","00"&x"07","00"&x"09","00"&x"0b","00"&x"0e","00"&x"12","00"&x"19","00"&x"20","00"&x"2c","00"&x"3b","00"&x"55","00"&x"72","00"&x"a6","00"&x"e8","01"&x"68","10"&x"1b",
	"00"&x"06","00"&x"09","00"&x"0b","00"&x"0d","00"&x"10","00"&x"14","00"&x"1b","00"&x"22","00"&x"2e","00"&x"3d","00"&x"57","00"&x"74","00"&x"a8","00"&x"ea","01"&x"6a","10"&x"1b",
	"00"&x"08","00"&x"0b","00"&x"0d","00"&x"0f","00"&x"12","00"&x"16","00"&x"1d","00"&x"24","00"&x"30","00"&x"3f","00"&x"59","00"&x"76","00"&x"a9","00"&x"eb","01"&x"6b","10"&x"1b",
	"00"&x"0c","00"&x"0e","00"&x"10","00"&x"12","00"&x"16","00"&x"1a","00"&x"20","00"&x"27","00"&x"34","00"&x"42","00"&x"5c","00"&x"79","00"&x"ac","00"&x"ee","01"&x"6c","10"&x"1b",
	"00"&x"0f","00"&x"12","00"&x"14","00"&x"16","00"&x"1a","00"&x"1d","00"&x"24","00"&x"2b","00"&x"37","00"&x"46","00"&x"5f","00"&x"7c","00"&x"af","00"&x"f1","01"&x"6e","10"&x"1c",
	"00"&x"16","00"&x"19","00"&x"1b","00"&x"1d","00"&x"20","00"&x"24","00"&x"2a","00"&x"31","00"&x"3e","00"&x"4c","00"&x"65","00"&x"81","00"&x"b5","00"&x"f5","01"&x"72","10"&x"1d",
	"00"&x"1d","00"&x"20","00"&x"22","00"&x"24","00"&x"27","00"&x"2b","00"&x"31","00"&x"39","00"&x"45","00"&x"53","00"&x"6c","00"&x"87","00"&x"bb","00"&x"fb","01"&x"77","10"&x"1f",
	"00"&x"2a","00"&x"2c","00"&x"2e","00"&x"30","00"&x"34","00"&x"37","00"&x"3e","00"&x"45","00"&x"51","00"&x"5f","00"&x"78","00"&x"92","00"&x"c5","01"&x"05","01"&x"7f","10"&x"22",
	"00"&x"38","00"&x"3b","00"&x"3d","00"&x"3f","00"&x"42","00"&x"46","00"&x"4c","00"&x"53","00"&x"5f","00"&x"6d","00"&x"84","00"&x"9f","00"&x"d2","01"&x"0f","01"&x"88","10"&x"28",
	"00"&x"52","00"&x"55","00"&x"57","00"&x"59","00"&x"5c","00"&x"5f","00"&x"65","00"&x"6c","00"&x"78","00"&x"84","00"&x"9a","00"&x"b6","00"&x"e8","01"&x"24","01"&x"9a","10"&x"34",
	"00"&x"70","00"&x"72","00"&x"74","00"&x"76","00"&x"79","00"&x"7c","00"&x"81","00"&x"87","00"&x"92","00"&x"9f","00"&x"b6","00"&x"d1","01"&x"02","01"&x"3d","01"&x"b0","10"&x"44",
	"00"&x"a4","00"&x"a6","00"&x"a8","00"&x"a9","00"&x"ac","00"&x"af","00"&x"b5","00"&x"bb","00"&x"c5","00"&x"d2","00"&x"e8","01"&x"02","01"&x"31","01"&x"6c","01"&x"dc","10"&x"69",
	"00"&x"e6","00"&x"e8","00"&x"ea","00"&x"eb","00"&x"ee","00"&x"f1","00"&x"f5","00"&x"fb","01"&x"05","01"&x"0f","01"&x"24","01"&x"3d","01"&x"6c","01"&x"a4","10"&x"14","10"&x"9a",
	"01"&x"67","01"&x"68","01"&x"6a","01"&x"6b","01"&x"6c","01"&x"6e","01"&x"72","01"&x"77","01"&x"7f","01"&x"88","01"&x"9a","01"&x"b0","01"&x"dc","10"&x"14","10"&x"79","10"&x"f3",
	"10"&x"1a","10"&x"1b","10"&x"1b","10"&x"1b","10"&x"1b","10"&x"1c","10"&x"1d","10"&x"1f","10"&x"22","10"&x"28","10"&x"34","10"&x"44","10"&x"69","10"&x"9a","10"&x"f3","11"&x"61",
	"00"&x"03","00"&x"06","00"&x"08","00"&x"0a","00"&x"0e","00"&x"11","00"&x"18","00"&x"1f","00"&x"2c","00"&x"3a","00"&x"54","00"&x"72","00"&x"a5","00"&x"e8","01"&x"68","10"&x"1a",
	"00"&x"06","00"&x"09","00"&x"0b","00"&x"0d","00"&x"10","00"&x"14","00"&x"1b","00"&x"22","00"&x"2e","00"&x"3d","00"&x"57","00"&x"74","00"&x"a8","00"&x"ea","01"&x"6a","10"&x"1b",
	"00"&x"08","00"&x"0b","00"&x"0d","00"&x"0f","00"&x"12","00"&x"16","00"&x"1d","00"&x"24","00"&x"30","00"&x"3f","00"&x"59","00"&x"76","00"&x"a9","00"&x"eb","01"&x"6b","10"&x"1b",
	"00"&x"0a","00"&x"0d","00"&x"0f","00"&x"11","00"&x"15","00"&x"18","00"&x"1f","00"&x"26","00"&x"33","00"&x"41","00"&x"5b","00"&x"78","00"&x"ab","00"&x"ed","01"&x"6c","10"&x"1b",
	"00"&x"0e","00"&x"10","00"&x"12","00"&x"15","00"&x"18","00"&x"1c","00"&x"22","00"&x"2a","00"&x"36","00"&x"44","00"&x"5e","00"&x"7b","00"&x"ae","00"&x"ef","01"&x"6e","10"&x"1c",
	"00"&x"11","00"&x"14","00"&x"16","00"&x"18","00"&x"1c","00"&x"20","00"&x"26","00"&x"2d","00"&x"3a","00"&x"48","00"&x"61","00"&x"7e","00"&x"b1","00"&x"f2","01"&x"70","10"&x"1c",
	"00"&x"18","00"&x"1b","00"&x"1d","00"&x"1f","00"&x"22","00"&x"26","00"&x"2c","00"&x"33","00"&x"40","00"&x"4e","00"&x"67","00"&x"83","00"&x"b6","00"&x"f7","01"&x"73","10"&x"1d",
	"00"&x"1f","00"&x"22","00"&x"24","00"&x"26","00"&x"2a","00"&x"2d","00"&x"33","00"&x"3b","00"&x"47","00"&x"55","00"&x"6e","00"&x"89","00"&x"bd","00"&x"fc","01"&x"78","10"&x"1f",
	"00"&x"2c","00"&x"2e","00"&x"30","00"&x"33","00"&x"36","00"&x"3a","00"&x"40","00"&x"47","00"&x"53","00"&x"61","00"&x"79","00"&x"94","00"&x"c7","01"&x"06","01"&x"7f","10"&x"23",
	"00"&x"3a","00"&x"3d","00"&x"3f","00"&x"41","00"&x"44","00"&x"48","00"&x"4e","00"&x"55","00"&x"61","00"&x"6f","00"&x"85","00"&x"a1","00"&x"d4","01"&x"10","01"&x"89","10"&x"28",
	"00"&x"54","00"&x"57","00"&x"59","00"&x"5b","00"&x"5e","00"&x"61","00"&x"67","00"&x"6e","00"&x"79","00"&x"85","00"&x"9c","00"&x"b8","00"&x"ea","01"&x"25","01"&x"9b","10"&x"34",
	"00"&x"72","00"&x"74","00"&x"76","00"&x"78","00"&x"7b","00"&x"7e","00"&x"83","00"&x"89","00"&x"94","00"&x"a1","00"&x"b8","00"&x"d3","01"&x"04","01"&x"3e","01"&x"b1","10"&x"44",
	"00"&x"a5","00"&x"a8","00"&x"a9","00"&x"ab","00"&x"ae","00"&x"b1","00"&x"b6","00"&x"bd","00"&x"c7","00"&x"d4","00"&x"ea","01"&x"04","01"&x"32","01"&x"6c","01"&x"dd","10"&x"69",
	"00"&x"e8","00"&x"ea","00"&x"eb","00"&x"ed","00"&x"ef","00"&x"f2","00"&x"f7","00"&x"fc","01"&x"06","01"&x"10","01"&x"25","01"&x"3e","01"&x"6c","01"&x"a5","10"&x"15","10"&x"9a",
	"01"&x"68","01"&x"6a","01"&x"6b","01"&x"6c","01"&x"6e","01"&x"70","01"&x"73","01"&x"78","01"&x"7f","01"&x"89","01"&x"9b","01"&x"b1","01"&x"dd","10"&x"15","10"&x"79","10"&x"f3",
	"10"&x"1a","10"&x"1b","10"&x"1b","10"&x"1b","10"&x"1c","10"&x"1c","10"&x"1d","10"&x"1f","10"&x"23","10"&x"28","10"&x"34","10"&x"44","10"&x"69","10"&x"9a","10"&x"f3","11"&x"61",
	"00"&x"06","00"&x"08","00"&x"0a","00"&x"0c","00"&x"10","00"&x"14","00"&x"1a","00"&x"21","00"&x"2e","00"&x"3d","00"&x"56","00"&x"74","00"&x"a7","00"&x"e9","01"&x"69","10"&x"1b",
	"00"&x"08","00"&x"0b","00"&x"0d","00"&x"0f","00"&x"12","00"&x"16","00"&x"1d","00"&x"24","00"&x"30","00"&x"3f","00"&x"59","00"&x"76","00"&x"a9","00"&x"eb","01"&x"6b","10"&x"1b",
	"00"&x"0a","00"&x"0d","00"&x"0f","00"&x"11","00"&x"15","00"&x"18","00"&x"1f","00"&x"26","00"&x"33","00"&x"41","00"&x"5b","00"&x"78","00"&x"ab","00"&x"ed","01"&x"6c","10"&x"1b",
	"00"&x"0c","00"&x"0f","00"&x"11","00"&x"13","00"&x"17","00"&x"1b","00"&x"21","00"&x"28","00"&x"35","00"&x"43","00"&x"5d","00"&x"7a","00"&x"ad","00"&x"ee","01"&x"6d","10"&x"1c",
	"00"&x"10","00"&x"12","00"&x"15","00"&x"17","00"&x"1a","00"&x"1e","00"&x"24","00"&x"2c","00"&x"38","00"&x"46","00"&x"60","00"&x"7d","00"&x"b0","00"&x"f1","01"&x"6f","10"&x"1c",
	"00"&x"14","00"&x"16","00"&x"18","00"&x"1b","00"&x"1e","00"&x"22","00"&x"28","00"&x"2f","00"&x"3c","00"&x"4a","00"&x"63","00"&x"80","00"&x"b3","00"&x"f4","01"&x"71","10"&x"1c",
	"00"&x"1a","00"&x"1d","00"&x"1f","00"&x"21","00"&x"24","00"&x"28","00"&x"2e","00"&x"35","00"&x"42","00"&x"50","00"&x"69","00"&x"84","00"&x"b8","00"&x"f8","01"&x"74","10"&x"1e",
	"00"&x"21","00"&x"24","00"&x"26","00"&x"28","00"&x"2c","00"&x"2f","00"&x"35","00"&x"3d","00"&x"49","00"&x"57","00"&x"70","00"&x"8a","00"&x"be","00"&x"fe","01"&x"79","10"&x"1f",
	"00"&x"2e","00"&x"30","00"&x"33","00"&x"35","00"&x"38","00"&x"3c","00"&x"42","00"&x"49","00"&x"55","00"&x"63","00"&x"7b","00"&x"95","00"&x"c9","01"&x"08","01"&x"80","10"&x"23",
	"00"&x"3d","00"&x"3f","00"&x"41","00"&x"43","00"&x"46","00"&x"4a","00"&x"50","00"&x"57","00"&x"63","00"&x"71","00"&x"87","00"&x"a3","00"&x"d5","01"&x"12","01"&x"8a","10"&x"29",
	"00"&x"56","00"&x"59","00"&x"5b","00"&x"5d","00"&x"60","00"&x"63","00"&x"69","00"&x"70","00"&x"7b","00"&x"87","00"&x"9e","00"&x"b9","00"&x"eb","01"&x"26","01"&x"9c","10"&x"34",
	"00"&x"74","00"&x"76","00"&x"78","00"&x"7a","00"&x"7d","00"&x"80","00"&x"84","00"&x"8a","00"&x"95","00"&x"a3","00"&x"b9","00"&x"d4","01"&x"05","01"&x"3f","01"&x"b1","10"&x"44",
	"00"&x"a7","00"&x"a9","00"&x"ab","00"&x"ad","00"&x"b0","00"&x"b3","00"&x"b8","00"&x"be","00"&x"c9","00"&x"d5","00"&x"eb","01"&x"05","01"&x"33","01"&x"6d","01"&x"dd","10"&x"69",
	"00"&x"e9","00"&x"eb","00"&x"ed","00"&x"ee","00"&x"f1","00"&x"f4","00"&x"f8","00"&x"fe","01"&x"08","01"&x"12","01"&x"26","01"&x"3f","01"&x"6d","01"&x"a5","10"&x"15","10"&x"9a",
	"01"&x"69","01"&x"6b","01"&x"6c","01"&x"6d","01"&x"6f","01"&x"71","01"&x"74","01"&x"79","01"&x"80","01"&x"8a","01"&x"9c","01"&x"b1","01"&x"dd","10"&x"15","10"&x"79","10"&x"f3",
	"10"&x"1b","10"&x"1b","10"&x"1b","10"&x"1c","10"&x"1c","10"&x"1c","10"&x"1e","10"&x"1f","10"&x"23","10"&x"29","10"&x"34","10"&x"44","10"&x"69","10"&x"9a","10"&x"f3","11"&x"61",
	"00"&x"09","00"&x"0c","00"&x"0e","00"&x"10","00"&x"13","00"&x"17","00"&x"1e","00"&x"25","00"&x"31","00"&x"40","00"&x"5a","00"&x"77","00"&x"aa","00"&x"ec","01"&x"6b","10"&x"1b",
	"00"&x"0c","00"&x"0e","00"&x"10","00"&x"12","00"&x"16","00"&x"1a","00"&x"20","00"&x"27","00"&x"34","00"&x"42","00"&x"5c","00"&x"79","00"&x"ac","00"&x"ee","01"&x"6c","10"&x"1b",
	"00"&x"0e","00"&x"10","00"&x"12","00"&x"15","00"&x"18","00"&x"1c","00"&x"22","00"&x"2a","00"&x"36","00"&x"44","00"&x"5e","00"&x"7b","00"&x"ae","00"&x"ef","01"&x"6e","10"&x"1c",
	"00"&x"10","00"&x"12","00"&x"15","00"&x"17","00"&x"1a","00"&x"1e","00"&x"24","00"&x"2c","00"&x"38","00"&x"46","00"&x"60","00"&x"7d","00"&x"b0","00"&x"f1","01"&x"6f","10"&x"1c",
	"00"&x"13","00"&x"16","00"&x"18","00"&x"1a","00"&x"1d","00"&x"21","00"&x"28","00"&x"2f","00"&x"3b","00"&x"4a","00"&x"63","00"&x"80","00"&x"b2","00"&x"f3","01"&x"70","10"&x"1c",
	"00"&x"17","00"&x"1a","00"&x"1c","00"&x"1e","00"&x"21","00"&x"25","00"&x"2c","00"&x"32","00"&x"3f","00"&x"4d","00"&x"66","00"&x"82","00"&x"b6","00"&x"f6","01"&x"72","10"&x"1d",
	"00"&x"1e","00"&x"20","00"&x"22","00"&x"24","00"&x"28","00"&x"2c","00"&x"32","00"&x"39","00"&x"45","00"&x"53","00"&x"6c","00"&x"87","00"&x"bb","00"&x"fb","01"&x"76","10"&x"1e",
	"00"&x"25","00"&x"27","00"&x"2a","00"&x"2c","00"&x"2f","00"&x"32","00"&x"39","00"&x"40","00"&x"4c","00"&x"5a","00"&x"73","00"&x"8d","00"&x"c1","01"&x"00","01"&x"7a","10"&x"20",
	"00"&x"31","00"&x"34","00"&x"36","00"&x"38","00"&x"3b","00"&x"3f","00"&x"45","00"&x"4c","00"&x"58","00"&x"66","00"&x"7e","00"&x"98","00"&x"cb","01"&x"0a","01"&x"82","10"&x"23",
	"00"&x"40","00"&x"42","00"&x"44","00"&x"46","00"&x"4a","00"&x"4d","00"&x"53","00"&x"5a","00"&x"66","00"&x"74","00"&x"8a","00"&x"a5","00"&x"d8","01"&x"14","01"&x"8c","10"&x"29",
	"00"&x"5a","00"&x"5c","00"&x"5e","00"&x"60","00"&x"63","00"&x"66","00"&x"6c","00"&x"73","00"&x"7e","00"&x"8a","00"&x"a1","00"&x"bc","00"&x"ed","01"&x"28","01"&x"9d","10"&x"34",
	"00"&x"77","00"&x"79","00"&x"7b","00"&x"7d","00"&x"80","00"&x"82","00"&x"87","00"&x"8d","00"&x"98","00"&x"a5","00"&x"bc","00"&x"d7","01"&x"07","01"&x"41","01"&x"b2","10"&x"44",
	"00"&x"aa","00"&x"ac","00"&x"ae","00"&x"b0","00"&x"b2","00"&x"b6","00"&x"bb","00"&x"c1","00"&x"cb","00"&x"d8","00"&x"ed","01"&x"07","01"&x"35","01"&x"6f","01"&x"de","10"&x"69",
	"00"&x"ec","00"&x"ee","00"&x"ef","00"&x"f1","00"&x"f3","00"&x"f6","00"&x"fb","01"&x"00","01"&x"0a","01"&x"14","01"&x"28","01"&x"41","01"&x"6f","01"&x"a6","10"&x"15","10"&x"9a",
	"01"&x"6b","01"&x"6c","01"&x"6e","01"&x"6f","01"&x"70","01"&x"72","01"&x"76","01"&x"7a","01"&x"82","01"&x"8c","01"&x"9d","01"&x"b2","01"&x"de","10"&x"15","10"&x"79","10"&x"f3",
	"10"&x"1b","10"&x"1b","10"&x"1c","10"&x"1c","10"&x"1c","10"&x"1d","10"&x"1e","10"&x"20","10"&x"23","10"&x"29","10"&x"34","10"&x"44","10"&x"69","10"&x"9a","10"&x"f3","11"&x"61",
	"00"&x"0d","00"&x"0f","00"&x"11","00"&x"14","00"&x"17","00"&x"1b","00"&x"21","00"&x"29","00"&x"35","00"&x"43","00"&x"5d","00"&x"7a","00"&x"ad","00"&x"ef","01"&x"6d","10"&x"1c",
	"00"&x"0f","00"&x"12","00"&x"14","00"&x"16","00"&x"1a","00"&x"1d","00"&x"24","00"&x"2b","00"&x"37","00"&x"46","00"&x"5f","00"&x"7c","00"&x"af","00"&x"f1","01"&x"6e","10"&x"1c",
	"00"&x"11","00"&x"14","00"&x"16","00"&x"18","00"&x"1c","00"&x"20","00"&x"26","00"&x"2d","00"&x"3a","00"&x"48","00"&x"61","00"&x"7e","00"&x"b1","00"&x"f2","01"&x"70","10"&x"1c",
	"00"&x"14","00"&x"16","00"&x"18","00"&x"1b","00"&x"1e","00"&x"22","00"&x"28","00"&x"2f","00"&x"3c","00"&x"4a","00"&x"63","00"&x"80","00"&x"b3","00"&x"f4","01"&x"71","10"&x"1c",
	"00"&x"17","00"&x"1a","00"&x"1c","00"&x"1e","00"&x"21","00"&x"25","00"&x"2c","00"&x"32","00"&x"3f","00"&x"4d","00"&x"66","00"&x"82","00"&x"b6","00"&x"f6","01"&x"72","10"&x"1d",
	"00"&x"1b","00"&x"1d","00"&x"20","00"&x"22","00"&x"25","00"&x"29","00"&x"2f","00"&x"36","00"&x"42","00"&x"51","00"&x"6a","00"&x"85","00"&x"b9","00"&x"f9","01"&x"74","10"&x"1e",
	"00"&x"21","00"&x"24","00"&x"26","00"&x"28","00"&x"2c","00"&x"2f","00"&x"35","00"&x"3c","00"&x"48","00"&x"57","00"&x"70","00"&x"8a","00"&x"be","00"&x"fe","01"&x"78","10"&x"1f",
	"00"&x"29","00"&x"2b","00"&x"2d","00"&x"2f","00"&x"32","00"&x"36","00"&x"3c","00"&x"43","00"&x"4f","00"&x"5d","00"&x"76","00"&x"90","00"&x"c4","01"&x"03","01"&x"7c","10"&x"20",
	"00"&x"35","00"&x"37","00"&x"3a","00"&x"3c","00"&x"3f","00"&x"42","00"&x"48","00"&x"4f","00"&x"5b","00"&x"69","00"&x"81","00"&x"9b","00"&x"ce","01"&x"0c","01"&x"84","10"&x"24",
	"00"&x"43","00"&x"46","00"&x"48","00"&x"4a","00"&x"4d","00"&x"51","00"&x"57","00"&x"5d","00"&x"69","00"&x"77","00"&x"8d","00"&x"a8","00"&x"db","01"&x"16","01"&x"8e","10"&x"29",
	"00"&x"5d","00"&x"5f","00"&x"61","00"&x"63","00"&x"66","00"&x"6a","00"&x"70","00"&x"76","00"&x"81","00"&x"8d","00"&x"a4","00"&x"bf","00"&x"f0","01"&x"2a","01"&x"9f","10"&x"35",
	"00"&x"7a","00"&x"7c","00"&x"7e","00"&x"80","00"&x"82","00"&x"85","00"&x"8a","00"&x"90","00"&x"9b","00"&x"a8","00"&x"bf","00"&x"da","01"&x"09","01"&x"43","01"&x"b4","10"&x"44",
	"00"&x"ad","00"&x"af","00"&x"b1","00"&x"b3","00"&x"b6","00"&x"b9","00"&x"be","00"&x"c4","00"&x"ce","00"&x"db","00"&x"f0","01"&x"09","01"&x"37","01"&x"71","01"&x"df","10"&x"69",
	"00"&x"ef","00"&x"f1","00"&x"f2","00"&x"f4","00"&x"f6","00"&x"f9","00"&x"fe","01"&x"03","01"&x"0c","01"&x"16","01"&x"2a","01"&x"43","01"&x"71","01"&x"a8","10"&x"16","10"&x"9a",
	"01"&x"6d","01"&x"6e","01"&x"70","01"&x"71","01"&x"72","01"&x"74","01"&x"78","01"&x"7c","01"&x"84","01"&x"8e","01"&x"9f","01"&x"b4","01"&x"df","10"&x"16","10"&x"79","10"&x"f3",
	"10"&x"1c","10"&x"1c","10"&x"1c","10"&x"1c","10"&x"1d","10"&x"1e","10"&x"1f","10"&x"20","10"&x"24","10"&x"29","10"&x"35","10"&x"44","10"&x"69","10"&x"9a","10"&x"f3","11"&x"61",
	"00"&x"13","00"&x"16","00"&x"18","00"&x"1a","00"&x"1e","00"&x"21","00"&x"28","00"&x"2f","00"&x"3b","00"&x"4a","00"&x"63","00"&x"80","00"&x"b3","00"&x"f4","01"&x"71","10"&x"1d",
	"00"&x"16","00"&x"19","00"&x"1b","00"&x"1d","00"&x"20","00"&x"24","00"&x"2a","00"&x"31","00"&x"3e","00"&x"4c","00"&x"65","00"&x"81","00"&x"b5","00"&x"f5","01"&x"72","10"&x"1d",
	"00"&x"18","00"&x"1b","00"&x"1d","00"&x"1f","00"&x"22","00"&x"26","00"&x"2c","00"&x"33","00"&x"40","00"&x"4e","00"&x"67","00"&x"83","00"&x"b6","00"&x"f7","01"&x"73","10"&x"1d",
	"00"&x"1a","00"&x"1d","00"&x"1f","00"&x"21","00"&x"24","00"&x"28","00"&x"2e","00"&x"35","00"&x"42","00"&x"50","00"&x"69","00"&x"84","00"&x"b8","00"&x"f8","01"&x"74","10"&x"1e",
	"00"&x"1e","00"&x"20","00"&x"22","00"&x"24","00"&x"28","00"&x"2c","00"&x"32","00"&x"39","00"&x"45","00"&x"53","00"&x"6c","00"&x"87","00"&x"bb","00"&x"fb","01"&x"76","10"&x"1e",
	"00"&x"21","00"&x"24","00"&x"26","00"&x"28","00"&x"2c","00"&x"2f","00"&x"35","00"&x"3c","00"&x"48","00"&x"57","00"&x"70","00"&x"8a","00"&x"be","00"&x"fe","01"&x"78","10"&x"1f",
	"00"&x"28","00"&x"2a","00"&x"2c","00"&x"2e","00"&x"32","00"&x"35","00"&x"3c","00"&x"43","00"&x"4f","00"&x"5d","00"&x"75","00"&x"90","00"&x"c3","01"&x"02","01"&x"7c","10"&x"20",
	"00"&x"2f","00"&x"31","00"&x"33","00"&x"35","00"&x"39","00"&x"3c","00"&x"43","00"&x"4a","00"&x"55","00"&x"63","00"&x"7c","00"&x"96","00"&x"c9","01"&x"08","01"&x"80","10"&x"21",
	"00"&x"3b","00"&x"3e","00"&x"40","00"&x"42","00"&x"45","00"&x"48","00"&x"4f","00"&x"55","00"&x"61","00"&x"6f","00"&x"85","00"&x"a1","00"&x"d3","01"&x"10","01"&x"87","10"&x"25",
	"00"&x"4a","00"&x"4c","00"&x"4e","00"&x"50","00"&x"53","00"&x"57","00"&x"5d","00"&x"63","00"&x"6f","00"&x"7d","00"&x"92","00"&x"ae","00"&x"e0","01"&x"1b","01"&x"91","10"&x"2a",
	"00"&x"63","00"&x"65","00"&x"67","00"&x"69","00"&x"6c","00"&x"70","00"&x"75","00"&x"7c","00"&x"85","00"&x"92","00"&x"a9","00"&x"c4","00"&x"f5","01"&x"2f","01"&x"a1","10"&x"35",
	"00"&x"80","00"&x"81","00"&x"83","00"&x"84","00"&x"87","00"&x"8a","00"&x"90","00"&x"96","00"&x"a1","00"&x"ae","00"&x"c4","00"&x"df","01"&x"0d","01"&x"47","01"&x"b6","10"&x"45",
	"00"&x"b3","00"&x"b5","00"&x"b6","00"&x"b8","00"&x"bb","00"&x"be","00"&x"c3","00"&x"c9","00"&x"d3","00"&x"e0","00"&x"f5","01"&x"0d","01"&x"3b","01"&x"74","01"&x"e0","10"&x"69",
	"00"&x"f4","00"&x"f5","00"&x"f7","00"&x"f8","00"&x"fb","00"&x"fe","01"&x"02","01"&x"08","01"&x"10","01"&x"1b","01"&x"2f","01"&x"47","01"&x"74","01"&x"aa","10"&x"17","10"&x"9a",
	"01"&x"71","01"&x"72","01"&x"73","01"&x"74","01"&x"76","01"&x"78","01"&x"7c","01"&x"80","01"&x"87","01"&x"91","01"&x"a1","01"&x"b6","01"&x"e0","10"&x"17","10"&x"79","10"&x"f3",
	"10"&x"1d","10"&x"1d","10"&x"1d","10"&x"1e","10"&x"1e","10"&x"1f","10"&x"20","10"&x"21","10"&x"25","10"&x"2a","10"&x"35","10"&x"45","10"&x"69","10"&x"9a","10"&x"f3","11"&x"61",
	"00"&x"1a","00"&x"1d","00"&x"1f","00"&x"21","00"&x"25","00"&x"29","00"&x"2f","00"&x"36","00"&x"42","00"&x"50","00"&x"6a","00"&x"85","00"&x"b9","00"&x"f9","01"&x"75","10"&x"1f",
	"00"&x"1d","00"&x"20","00"&x"22","00"&x"24","00"&x"27","00"&x"2b","00"&x"31","00"&x"39","00"&x"45","00"&x"53","00"&x"6c","00"&x"87","00"&x"bb","00"&x"fb","01"&x"77","10"&x"1f",
	"00"&x"1f","00"&x"22","00"&x"24","00"&x"26","00"&x"2a","00"&x"2d","00"&x"33","00"&x"3b","00"&x"47","00"&x"55","00"&x"6e","00"&x"89","00"&x"bd","00"&x"fc","01"&x"78","10"&x"1f",
	"00"&x"21","00"&x"24","00"&x"26","00"&x"28","00"&x"2c","00"&x"2f","00"&x"35","00"&x"3d","00"&x"49","00"&x"57","00"&x"70","00"&x"8a","00"&x"be","00"&x"fe","01"&x"79","10"&x"1f",
	"00"&x"25","00"&x"27","00"&x"2a","00"&x"2c","00"&x"2f","00"&x"32","00"&x"39","00"&x"40","00"&x"4c","00"&x"5a","00"&x"73","00"&x"8d","00"&x"c1","01"&x"00","01"&x"7a","10"&x"20",
	"00"&x"29","00"&x"2b","00"&x"2d","00"&x"2f","00"&x"32","00"&x"36","00"&x"3c","00"&x"43","00"&x"4f","00"&x"5d","00"&x"76","00"&x"90","00"&x"c4","01"&x"03","01"&x"7c","10"&x"20",
	"00"&x"2f","00"&x"31","00"&x"33","00"&x"35","00"&x"39","00"&x"3c","00"&x"43","00"&x"4a","00"&x"55","00"&x"63","00"&x"7c","00"&x"96","00"&x"c9","01"&x"08","01"&x"80","10"&x"21",
	"00"&x"36","00"&x"39","00"&x"3b","00"&x"3d","00"&x"40","00"&x"43","00"&x"4a","00"&x"50","00"&x"5c","00"&x"6a","00"&x"82","00"&x"9c","00"&x"cf","01"&x"0c","01"&x"84","10"&x"23",
	"00"&x"42","00"&x"45","00"&x"47","00"&x"49","00"&x"4c","00"&x"4f","00"&x"55","00"&x"5c","00"&x"68","00"&x"76","00"&x"8c","00"&x"a7","00"&x"d9","01"&x"15","01"&x"8b","10"&x"26",
	"00"&x"50","00"&x"53","00"&x"55","00"&x"57","00"&x"5a","00"&x"5d","00"&x"63","00"&x"6a","00"&x"76","00"&x"82","00"&x"99","00"&x"b4","00"&x"e5","01"&x"20","01"&x"94","10"&x"2c",
	"00"&x"6a","00"&x"6c","00"&x"6e","00"&x"70","00"&x"73","00"&x"76","00"&x"7c","00"&x"82","00"&x"8c","00"&x"99","00"&x"af","00"&x"ca","00"&x"fa","01"&x"33","01"&x"a4","10"&x"36",
	"00"&x"85","00"&x"87","00"&x"89","00"&x"8a","00"&x"8d","00"&x"90","00"&x"96","00"&x"9c","00"&x"a7","00"&x"b4","00"&x"ca","00"&x"e4","01"&x"11","01"&x"4b","01"&x"b9","10"&x"46",
	"00"&x"b9","00"&x"bb","00"&x"bd","00"&x"be","00"&x"c1","00"&x"c4","00"&x"c9","00"&x"cf","00"&x"d9","00"&x"e5","00"&x"fa","01"&x"11","01"&x"3f","01"&x"78","01"&x"e3","10"&x"6a",
	"00"&x"f9","00"&x"fb","00"&x"fc","00"&x"fe","01"&x"00","01"&x"03","01"&x"08","01"&x"0c","01"&x"15","01"&x"20","01"&x"33","01"&x"4b","01"&x"78","01"&x"ad","10"&x"18","10"&x"9a",
	"01"&x"75","01"&x"77","01"&x"78","01"&x"79","01"&x"7a","01"&x"7c","01"&x"80","01"&x"84","01"&x"8b","01"&x"94","01"&x"a4","01"&x"b9","01"&x"e3","10"&x"18","10"&x"79","10"&x"f3",
	"10"&x"1f","10"&x"1f","10"&x"1f","10"&x"1f","10"&x"20","10"&x"20","10"&x"21","10"&x"23","10"&x"26","10"&x"2c","10"&x"36","10"&x"46","10"&x"6a","10"&x"9a","10"&x"f3","11"&x"61",
	"00"&x"27","00"&x"2a","00"&x"2c","00"&x"2e","00"&x"31","00"&x"35","00"&x"3b","00"&x"42","00"&x"4e","00"&x"5c","00"&x"75","00"&x"90","00"&x"c3","01"&x"03","01"&x"7d","10"&x"22",
	"00"&x"2a","00"&x"2c","00"&x"2e","00"&x"30","00"&x"34","00"&x"37","00"&x"3e","00"&x"45","00"&x"51","00"&x"5f","00"&x"78","00"&x"92","00"&x"c5","01"&x"05","01"&x"7f","10"&x"22",
	"00"&x"2c","00"&x"2e","00"&x"30","00"&x"33","00"&x"36","00"&x"3a","00"&x"40","00"&x"47","00"&x"53","00"&x"61","00"&x"79","00"&x"94","00"&x"c7","01"&x"06","01"&x"7f","10"&x"23",
	"00"&x"2e","00"&x"30","00"&x"33","00"&x"35","00"&x"38","00"&x"3c","00"&x"42","00"&x"49","00"&x"55","00"&x"63","00"&x"7b","00"&x"95","00"&x"c9","01"&x"08","01"&x"80","10"&x"23",
	"00"&x"31","00"&x"34","00"&x"36","00"&x"38","00"&x"3b","00"&x"3f","00"&x"45","00"&x"4c","00"&x"58","00"&x"66","00"&x"7e","00"&x"98","00"&x"cb","01"&x"0a","01"&x"82","10"&x"23",
	"00"&x"35","00"&x"37","00"&x"3a","00"&x"3c","00"&x"3f","00"&x"42","00"&x"48","00"&x"4f","00"&x"5b","00"&x"69","00"&x"81","00"&x"9b","00"&x"ce","01"&x"0c","01"&x"84","10"&x"24",
	"00"&x"3b","00"&x"3e","00"&x"40","00"&x"42","00"&x"45","00"&x"48","00"&x"4f","00"&x"55","00"&x"61","00"&x"6f","00"&x"85","00"&x"a1","00"&x"d3","01"&x"10","01"&x"87","10"&x"25",
	"00"&x"42","00"&x"45","00"&x"47","00"&x"49","00"&x"4c","00"&x"4f","00"&x"55","00"&x"5c","00"&x"68","00"&x"76","00"&x"8c","00"&x"a7","00"&x"d9","01"&x"15","01"&x"8b","10"&x"26",
	"00"&x"4e","00"&x"51","00"&x"53","00"&x"55","00"&x"58","00"&x"5b","00"&x"61","00"&x"68","00"&x"74","00"&x"81","00"&x"97","00"&x"b2","00"&x"e3","01"&x"1e","01"&x"92","10"&x"2a",
	"00"&x"5c","00"&x"5f","00"&x"61","00"&x"63","00"&x"66","00"&x"69","00"&x"6f","00"&x"76","00"&x"81","00"&x"8c","00"&x"a3","00"&x"be","00"&x"ef","01"&x"29","01"&x"9b","10"&x"2f",
	"00"&x"75","00"&x"78","00"&x"79","00"&x"7b","00"&x"7e","00"&x"81","00"&x"85","00"&x"8c","00"&x"97","00"&x"a3","00"&x"ba","00"&x"d4","01"&x"03","01"&x"3c","01"&x"aa","10"&x"39",
	"00"&x"90","00"&x"92","00"&x"94","00"&x"95","00"&x"98","00"&x"9b","00"&x"a1","00"&x"a7","00"&x"b2","00"&x"be","00"&x"d4","00"&x"ee","01"&x"1a","01"&x"53","01"&x"bf","10"&x"48",
	"00"&x"c3","00"&x"c5","00"&x"c7","00"&x"c9","00"&x"cb","00"&x"ce","00"&x"d3","00"&x"d9","00"&x"e3","00"&x"ef","01"&x"03","01"&x"1a","01"&x"47","01"&x"7f","01"&x"e7","10"&x"6b",
	"01"&x"03","01"&x"05","01"&x"06","01"&x"08","01"&x"0a","01"&x"0c","01"&x"10","01"&x"15","01"&x"1e","01"&x"29","01"&x"3c","01"&x"53","01"&x"7f","01"&x"b3","10"&x"1b","10"&x"9b",
	"01"&x"7d","01"&x"7f","01"&x"7f","01"&x"80","01"&x"82","01"&x"84","01"&x"87","01"&x"8b","01"&x"92","01"&x"9b","01"&x"aa","01"&x"bf","01"&x"e7","10"&x"1b","10"&x"7a","10"&x"f3",
	"10"&x"22","10"&x"22","10"&x"23","10"&x"23","10"&x"23","10"&x"24","10"&x"25","10"&x"26","10"&x"2a","10"&x"2f","10"&x"39","10"&x"48","10"&x"6b","10"&x"9b","10"&x"f3","11"&x"61",
	"00"&x"36","00"&x"38","00"&x"3a","00"&x"3d","00"&x"40","00"&x"43","00"&x"4a","00"&x"50","00"&x"5c","00"&x"6a","00"&x"82","00"&x"9d","00"&x"d0","01"&x"0e","01"&x"87","10"&x"28",
	"00"&x"38","00"&x"3b","00"&x"3d","00"&x"3f","00"&x"42","00"&x"46","00"&x"4c","00"&x"53","00"&x"5f","00"&x"6d","00"&x"84","00"&x"9f","00"&x"d2","01"&x"0f","01"&x"88","10"&x"28",
	"00"&x"3a","00"&x"3d","00"&x"3f","00"&x"41","00"&x"44","00"&x"48","00"&x"4e","00"&x"55","00"&x"61","00"&x"6f","00"&x"85","00"&x"a1","00"&x"d4","01"&x"10","01"&x"89","10"&x"28",
	"00"&x"3d","00"&x"3f","00"&x"41","00"&x"43","00"&x"46","00"&x"4a","00"&x"50","00"&x"57","00"&x"63","00"&x"71","00"&x"87","00"&x"a3","00"&x"d5","01"&x"12","01"&x"8a","10"&x"29",
	"00"&x"40","00"&x"42","00"&x"44","00"&x"46","00"&x"4a","00"&x"4d","00"&x"53","00"&x"5a","00"&x"66","00"&x"74","00"&x"8a","00"&x"a5","00"&x"d8","01"&x"14","01"&x"8c","10"&x"29",
	"00"&x"43","00"&x"46","00"&x"48","00"&x"4a","00"&x"4d","00"&x"51","00"&x"57","00"&x"5d","00"&x"69","00"&x"77","00"&x"8d","00"&x"a8","00"&x"db","01"&x"16","01"&x"8e","10"&x"29",
	"00"&x"4a","00"&x"4c","00"&x"4e","00"&x"50","00"&x"53","00"&x"57","00"&x"5d","00"&x"63","00"&x"6f","00"&x"7d","00"&x"92","00"&x"ae","00"&x"e0","01"&x"1b","01"&x"91","10"&x"2a",
	"00"&x"50","00"&x"53","00"&x"55","00"&x"57","00"&x"5a","00"&x"5d","00"&x"63","00"&x"6a","00"&x"76","00"&x"82","00"&x"99","00"&x"b4","00"&x"e5","01"&x"20","01"&x"94","10"&x"2c",
	"00"&x"5c","00"&x"5f","00"&x"61","00"&x"63","00"&x"66","00"&x"69","00"&x"6f","00"&x"76","00"&x"81","00"&x"8c","00"&x"a3","00"&x"be","00"&x"ef","01"&x"29","01"&x"9b","10"&x"2f",
	"00"&x"6a","00"&x"6d","00"&x"6f","00"&x"71","00"&x"74","00"&x"77","00"&x"7d","00"&x"82","00"&x"8c","00"&x"99","00"&x"b0","00"&x"cb","00"&x"fb","01"&x"33","01"&x"a2","10"&x"34",
	"00"&x"82","00"&x"84","00"&x"85","00"&x"87","00"&x"8a","00"&x"8d","00"&x"92","00"&x"99","00"&x"a3","00"&x"b0","00"&x"c6","00"&x"e0","01"&x"0d","01"&x"46","01"&x"b2","10"&x"3d",
	"00"&x"9d","00"&x"9f","00"&x"a1","00"&x"a3","00"&x"a5","00"&x"a8","00"&x"ae","00"&x"b4","00"&x"be","00"&x"cb","00"&x"e0","00"&x"f9","01"&x"25","01"&x"5d","01"&x"c6","10"&x"4c",
	"00"&x"d0","00"&x"d2","00"&x"d4","00"&x"d5","00"&x"d8","00"&x"db","00"&x"e0","00"&x"e5","00"&x"ef","00"&x"fb","01"&x"0d","01"&x"25","01"&x"51","01"&x"87","01"&x"ed","10"&x"6e",
	"01"&x"0e","01"&x"0f","01"&x"10","01"&x"12","01"&x"14","01"&x"16","01"&x"1b","01"&x"20","01"&x"29","01"&x"33","01"&x"46","01"&x"5d","01"&x"87","01"&x"ba","10"&x"20","10"&x"9c",
	"01"&x"87","01"&x"88","01"&x"89","01"&x"8a","01"&x"8c","01"&x"8e","01"&x"91","01"&x"94","01"&x"9b","01"&x"a2","01"&x"b2","01"&x"c6","01"&x"ed","10"&x"20","10"&x"7c","10"&x"f3",
	"10"&x"28","10"&x"28","10"&x"28","10"&x"29","10"&x"29","10"&x"29","10"&x"2a","10"&x"2c","10"&x"2f","10"&x"34","10"&x"3d","10"&x"4c","10"&x"6e","10"&x"9c","10"&x"f3","11"&x"61",
	"00"&x"50","00"&x"52","00"&x"54","00"&x"56","00"&x"5a","00"&x"5d","00"&x"63","00"&x"6a","00"&x"75","00"&x"82","00"&x"98","00"&x"b4","00"&x"e6","01"&x"22","01"&x"99","10"&x"34",
	"00"&x"52","00"&x"55","00"&x"57","00"&x"59","00"&x"5c","00"&x"5f","00"&x"65","00"&x"6c","00"&x"78","00"&x"84","00"&x"9a","00"&x"b6","00"&x"e8","01"&x"24","01"&x"9a","10"&x"34",
	"00"&x"54","00"&x"57","00"&x"59","00"&x"5b","00"&x"5e","00"&x"61","00"&x"67","00"&x"6e","00"&x"79","00"&x"85","00"&x"9c","00"&x"b8","00"&x"ea","01"&x"25","01"&x"9b","10"&x"34",
	"00"&x"56","00"&x"59","00"&x"5b","00"&x"5d","00"&x"60","00"&x"63","00"&x"69","00"&x"70","00"&x"7b","00"&x"87","00"&x"9e","00"&x"b9","00"&x"eb","01"&x"26","01"&x"9c","10"&x"34",
	"00"&x"5a","00"&x"5c","00"&x"5e","00"&x"60","00"&x"63","00"&x"66","00"&x"6c","00"&x"73","00"&x"7e","00"&x"8a","00"&x"a1","00"&x"bc","00"&x"ed","01"&x"28","01"&x"9d","10"&x"34",
	"00"&x"5d","00"&x"5f","00"&x"61","00"&x"63","00"&x"66","00"&x"6a","00"&x"70","00"&x"76","00"&x"81","00"&x"8d","00"&x"a4","00"&x"bf","00"&x"f0","01"&x"2a","01"&x"9f","10"&x"35",
	"00"&x"63","00"&x"65","00"&x"67","00"&x"69","00"&x"6c","00"&x"70","00"&x"75","00"&x"7c","00"&x"85","00"&x"92","00"&x"a9","00"&x"c4","00"&x"f5","01"&x"2f","01"&x"a1","10"&x"35",
	"00"&x"6a","00"&x"6c","00"&x"6e","00"&x"70","00"&x"73","00"&x"76","00"&x"7c","00"&x"82","00"&x"8c","00"&x"99","00"&x"af","00"&x"ca","00"&x"fa","01"&x"33","01"&x"a4","10"&x"36",
	"00"&x"75","00"&x"78","00"&x"79","00"&x"7b","00"&x"7e","00"&x"81","00"&x"85","00"&x"8c","00"&x"97","00"&x"a3","00"&x"ba","00"&x"d4","01"&x"03","01"&x"3c","01"&x"aa","10"&x"39",
	"00"&x"82","00"&x"84","00"&x"85","00"&x"87","00"&x"8a","00"&x"8d","00"&x"92","00"&x"99","00"&x"a3","00"&x"b0","00"&x"c6","00"&x"e0","01"&x"0d","01"&x"46","01"&x"b2","10"&x"3d",
	"00"&x"98","00"&x"9a","00"&x"9c","00"&x"9e","00"&x"a1","00"&x"a4","00"&x"a9","00"&x"af","00"&x"ba","00"&x"c6","00"&x"dc","00"&x"f5","01"&x"21","01"&x"58","01"&x"c2","10"&x"47",
	"00"&x"b4","00"&x"b6","00"&x"b8","00"&x"b9","00"&x"bc","00"&x"bf","00"&x"c4","00"&x"ca","00"&x"d4","00"&x"e0","00"&x"f5","01"&x"0c","01"&x"38","01"&x"6e","01"&x"d5","10"&x"55",
	"00"&x"e6","00"&x"e8","00"&x"ea","00"&x"eb","00"&x"ed","00"&x"f0","00"&x"f5","00"&x"fa","01"&x"03","01"&x"0d","01"&x"21","01"&x"38","01"&x"63","01"&x"97","01"&x"fa","10"&x"75",
	"01"&x"22","01"&x"24","01"&x"25","01"&x"26","01"&x"28","01"&x"2a","01"&x"2f","01"&x"33","01"&x"3c","01"&x"46","01"&x"58","01"&x"6e","01"&x"97","01"&x"c8","10"&x"2a","10"&x"a0",
	"01"&x"99","01"&x"9a","01"&x"9b","01"&x"9c","01"&x"9d","01"&x"9f","01"&x"a1","01"&x"a4","01"&x"aa","01"&x"b2","01"&x"c2","01"&x"d5","01"&x"fa","10"&x"2a","10"&x"82","10"&x"f5",
	"10"&x"34","10"&x"34","10"&x"34","10"&x"34","10"&x"34","10"&x"35","10"&x"35","10"&x"36","10"&x"39","10"&x"3d","10"&x"47","10"&x"55","10"&x"75","10"&x"a0","10"&x"f5","11"&x"61",
	"00"&x"6e","00"&x"70","00"&x"72","00"&x"74","00"&x"77","00"&x"7a","00"&x"80","00"&x"85","00"&x"90","00"&x"9d","00"&x"b4","00"&x"cf","01"&x"01","01"&x"3b","01"&x"af","10"&x"44",
	"00"&x"70","00"&x"72","00"&x"74","00"&x"76","00"&x"79","00"&x"7c","00"&x"81","00"&x"87","00"&x"92","00"&x"9f","00"&x"b6","00"&x"d1","01"&x"02","01"&x"3d","01"&x"b0","10"&x"44",
	"00"&x"72","00"&x"74","00"&x"76","00"&x"78","00"&x"7b","00"&x"7e","00"&x"83","00"&x"89","00"&x"94","00"&x"a1","00"&x"b8","00"&x"d3","01"&x"04","01"&x"3e","01"&x"b1","10"&x"44",
	"00"&x"74","00"&x"76","00"&x"78","00"&x"7a","00"&x"7d","00"&x"80","00"&x"84","00"&x"8a","00"&x"95","00"&x"a3","00"&x"b9","00"&x"d4","01"&x"05","01"&x"3f","01"&x"b1","10"&x"44",
	"00"&x"77","00"&x"79","00"&x"7b","00"&x"7d","00"&x"80","00"&x"82","00"&x"87","00"&x"8d","00"&x"98","00"&x"a5","00"&x"bc","00"&x"d7","01"&x"07","01"&x"41","01"&x"b2","10"&x"44",
	"00"&x"7a","00"&x"7c","00"&x"7e","00"&x"80","00"&x"82","00"&x"85","00"&x"8a","00"&x"90","00"&x"9b","00"&x"a8","00"&x"bf","00"&x"da","01"&x"09","01"&x"43","01"&x"b4","10"&x"44",
	"00"&x"80","00"&x"81","00"&x"83","00"&x"84","00"&x"87","00"&x"8a","00"&x"90","00"&x"96","00"&x"a1","00"&x"ae","00"&x"c4","00"&x"df","01"&x"0d","01"&x"47","01"&x"b6","10"&x"45",
	"00"&x"85","00"&x"87","00"&x"89","00"&x"8a","00"&x"8d","00"&x"90","00"&x"96","00"&x"9c","00"&x"a7","00"&x"b4","00"&x"ca","00"&x"e4","01"&x"11","01"&x"4b","01"&x"b9","10"&x"46",
	"00"&x"90","00"&x"92","00"&x"94","00"&x"95","00"&x"98","00"&x"9b","00"&x"a1","00"&x"a7","00"&x"b2","00"&x"be","00"&x"d4","00"&x"ee","01"&x"1a","01"&x"53","01"&x"bf","10"&x"48",
	"00"&x"9d","00"&x"9f","00"&x"a1","00"&x"a3","00"&x"a5","00"&x"a8","00"&x"ae","00"&x"b4","00"&x"be","00"&x"cb","00"&x"e0","00"&x"f9","01"&x"25","01"&x"5d","01"&x"c6","10"&x"4c",
	"00"&x"b4","00"&x"b6","00"&x"b8","00"&x"b9","00"&x"bc","00"&x"bf","00"&x"c4","00"&x"ca","00"&x"d4","00"&x"e0","00"&x"f5","01"&x"0c","01"&x"38","01"&x"6e","01"&x"d5","10"&x"55",
	"00"&x"cf","00"&x"d1","00"&x"d3","00"&x"d4","00"&x"d7","00"&x"da","00"&x"df","00"&x"e4","00"&x"ee","00"&x"f9","01"&x"0c","01"&x"23","01"&x"4e","01"&x"84","01"&x"e7","10"&x"63",
	"01"&x"01","01"&x"02","01"&x"04","01"&x"05","01"&x"07","01"&x"09","01"&x"0d","01"&x"11","01"&x"1a","01"&x"25","01"&x"38","01"&x"4e","01"&x"78","01"&x"a9","10"&x"0b","10"&x"80",
	"01"&x"3b","01"&x"3d","01"&x"3e","01"&x"3f","01"&x"41","01"&x"43","01"&x"47","01"&x"4b","01"&x"53","01"&x"5d","01"&x"6e","01"&x"84","01"&x"a9","01"&x"da","10"&x"37","10"&x"a9",
	"01"&x"af","01"&x"b0","01"&x"b1","01"&x"b1","01"&x"b2","01"&x"b4","01"&x"b6","01"&x"b9","01"&x"bf","01"&x"c6","01"&x"d5","01"&x"e7","10"&x"0b","10"&x"37","10"&x"8c","10"&x"f9",
	"10"&x"44","10"&x"44","10"&x"44","10"&x"44","10"&x"44","10"&x"44","10"&x"45","10"&x"46","10"&x"48","10"&x"4c","10"&x"55","10"&x"63","10"&x"80","10"&x"a9","10"&x"f9","11"&x"61",
	"00"&x"a1","00"&x"a4","00"&x"a5","00"&x"a7","00"&x"aa","00"&x"ad","00"&x"b3","00"&x"b9","00"&x"c3","00"&x"d0","00"&x"e6","01"&x"01","01"&x"2f","01"&x"6a","01"&x"dc","10"&x"69",
	"00"&x"a4","00"&x"a6","00"&x"a8","00"&x"a9","00"&x"ac","00"&x"af","00"&x"b5","00"&x"bb","00"&x"c5","00"&x"d2","00"&x"e8","01"&x"02","01"&x"31","01"&x"6c","01"&x"dc","10"&x"69",
	"00"&x"a5","00"&x"a8","00"&x"a9","00"&x"ab","00"&x"ae","00"&x"b1","00"&x"b6","00"&x"bd","00"&x"c7","00"&x"d4","00"&x"ea","01"&x"04","01"&x"32","01"&x"6c","01"&x"dd","10"&x"69",
	"00"&x"a7","00"&x"a9","00"&x"ab","00"&x"ad","00"&x"b0","00"&x"b3","00"&x"b8","00"&x"be","00"&x"c9","00"&x"d5","00"&x"eb","01"&x"05","01"&x"33","01"&x"6d","01"&x"dd","10"&x"69",
	"00"&x"aa","00"&x"ac","00"&x"ae","00"&x"b0","00"&x"b2","00"&x"b6","00"&x"bb","00"&x"c1","00"&x"cb","00"&x"d8","00"&x"ed","01"&x"07","01"&x"35","01"&x"6f","01"&x"de","10"&x"69",
	"00"&x"ad","00"&x"af","00"&x"b1","00"&x"b3","00"&x"b6","00"&x"b9","00"&x"be","00"&x"c4","00"&x"ce","00"&x"db","00"&x"f0","01"&x"09","01"&x"37","01"&x"71","01"&x"df","10"&x"69",
	"00"&x"b3","00"&x"b5","00"&x"b6","00"&x"b8","00"&x"bb","00"&x"be","00"&x"c3","00"&x"c9","00"&x"d3","00"&x"e0","00"&x"f5","01"&x"0d","01"&x"3b","01"&x"74","01"&x"e0","10"&x"69",
	"00"&x"b9","00"&x"bb","00"&x"bd","00"&x"be","00"&x"c1","00"&x"c4","00"&x"c9","00"&x"cf","00"&x"d9","00"&x"e5","00"&x"fa","01"&x"11","01"&x"3f","01"&x"78","01"&x"e3","10"&x"6a",
	"00"&x"c3","00"&x"c5","00"&x"c7","00"&x"c9","00"&x"cb","00"&x"ce","00"&x"d3","00"&x"d9","00"&x"e3","00"&x"ef","01"&x"03","01"&x"1a","01"&x"47","01"&x"7f","01"&x"e7","10"&x"6b",
	"00"&x"d0","00"&x"d2","00"&x"d4","00"&x"d5","00"&x"d8","00"&x"db","00"&x"e0","00"&x"e5","00"&x"ef","00"&x"fb","01"&x"0d","01"&x"25","01"&x"51","01"&x"87","01"&x"ed","10"&x"6e",
	"00"&x"e6","00"&x"e8","00"&x"ea","00"&x"eb","00"&x"ed","00"&x"f0","00"&x"f5","00"&x"fa","01"&x"03","01"&x"0d","01"&x"21","01"&x"38","01"&x"63","01"&x"97","01"&x"fa","10"&x"75",
	"01"&x"01","01"&x"02","01"&x"04","01"&x"05","01"&x"07","01"&x"09","01"&x"0d","01"&x"11","01"&x"1a","01"&x"25","01"&x"38","01"&x"4e","01"&x"78","01"&x"a9","10"&x"0b","10"&x"80",
	"01"&x"2f","01"&x"31","01"&x"32","01"&x"33","01"&x"35","01"&x"37","01"&x"3b","01"&x"3f","01"&x"47","01"&x"51","01"&x"63","01"&x"78","01"&x"9e","01"&x"ce","10"&x"2c","10"&x"9b",
	"01"&x"6a","01"&x"6c","01"&x"6c","01"&x"6d","01"&x"6f","01"&x"71","01"&x"74","01"&x"78","01"&x"7f","01"&x"87","01"&x"97","01"&x"a9","01"&x"ce","01"&x"fd","10"&x"54","10"&x"c0",
	"01"&x"dc","01"&x"dc","01"&x"dd","01"&x"dd","01"&x"de","01"&x"df","01"&x"e0","01"&x"e3","01"&x"e7","01"&x"ed","01"&x"fa","10"&x"0b","10"&x"2c","10"&x"54","10"&x"a4","11"&x"09",
	"10"&x"69","10"&x"69","10"&x"69","10"&x"69","10"&x"69","10"&x"69","10"&x"69","10"&x"6a","10"&x"6b","10"&x"6e","10"&x"75","10"&x"80","10"&x"9b","10"&x"c0","11"&x"09","11"&x"67",
	"00"&x"e4","00"&x"e6","00"&x"e8","00"&x"e9","00"&x"ec","00"&x"ef","00"&x"f4","00"&x"f9","01"&x"03","01"&x"0e","01"&x"22","01"&x"3b","01"&x"6a","01"&x"a3","10"&x"14","10"&x"9a",
	"00"&x"e6","00"&x"e8","00"&x"ea","00"&x"eb","00"&x"ee","00"&x"f1","00"&x"f5","00"&x"fb","01"&x"05","01"&x"0f","01"&x"24","01"&x"3d","01"&x"6c","01"&x"a4","10"&x"14","10"&x"9a",
	"00"&x"e8","00"&x"ea","00"&x"eb","00"&x"ed","00"&x"ef","00"&x"f2","00"&x"f7","00"&x"fc","01"&x"06","01"&x"10","01"&x"25","01"&x"3e","01"&x"6c","01"&x"a5","10"&x"15","10"&x"9a",
	"00"&x"e9","00"&x"eb","00"&x"ed","00"&x"ee","00"&x"f1","00"&x"f4","00"&x"f8","00"&x"fe","01"&x"08","01"&x"12","01"&x"26","01"&x"3f","01"&x"6d","01"&x"a5","10"&x"15","10"&x"9a",
	"00"&x"ec","00"&x"ee","00"&x"ef","00"&x"f1","00"&x"f3","00"&x"f6","00"&x"fb","01"&x"00","01"&x"0a","01"&x"14","01"&x"28","01"&x"41","01"&x"6f","01"&x"a6","10"&x"15","10"&x"9a",
	"00"&x"ef","00"&x"f1","00"&x"f2","00"&x"f4","00"&x"f6","00"&x"f9","00"&x"fe","01"&x"03","01"&x"0c","01"&x"16","01"&x"2a","01"&x"43","01"&x"71","01"&x"a8","10"&x"16","10"&x"9a",
	"00"&x"f4","00"&x"f5","00"&x"f7","00"&x"f8","00"&x"fb","00"&x"fe","01"&x"02","01"&x"08","01"&x"10","01"&x"1b","01"&x"2f","01"&x"47","01"&x"74","01"&x"aa","10"&x"17","10"&x"9a",
	"00"&x"f9","00"&x"fb","00"&x"fc","00"&x"fe","01"&x"00","01"&x"03","01"&x"08","01"&x"0c","01"&x"15","01"&x"20","01"&x"33","01"&x"4b","01"&x"78","01"&x"ad","10"&x"18","10"&x"9a",
	"01"&x"03","01"&x"05","01"&x"06","01"&x"08","01"&x"0a","01"&x"0c","01"&x"10","01"&x"15","01"&x"1e","01"&x"29","01"&x"3c","01"&x"53","01"&x"7f","01"&x"b3","10"&x"1b","10"&x"9b",
	"01"&x"0e","01"&x"0f","01"&x"10","01"&x"12","01"&x"14","01"&x"16","01"&x"1b","01"&x"20","01"&x"29","01"&x"33","01"&x"46","01"&x"5d","01"&x"87","01"&x"ba","10"&x"20","10"&x"9c",
	"01"&x"22","01"&x"24","01"&x"25","01"&x"26","01"&x"28","01"&x"2a","01"&x"2f","01"&x"33","01"&x"3c","01"&x"46","01"&x"58","01"&x"6e","01"&x"97","01"&x"c8","10"&x"2a","10"&x"a0",
	"01"&x"3b","01"&x"3d","01"&x"3e","01"&x"3f","01"&x"41","01"&x"43","01"&x"47","01"&x"4b","01"&x"53","01"&x"5d","01"&x"6e","01"&x"84","01"&x"a9","01"&x"da","10"&x"37","10"&x"a9",
	"01"&x"6a","01"&x"6c","01"&x"6c","01"&x"6d","01"&x"6f","01"&x"71","01"&x"74","01"&x"78","01"&x"7f","01"&x"87","01"&x"97","01"&x"a9","01"&x"ce","01"&x"fd","10"&x"54","10"&x"c0",
	"01"&x"a3","01"&x"a4","01"&x"a5","01"&x"a5","01"&x"a6","01"&x"a8","01"&x"aa","01"&x"ad","01"&x"b3","01"&x"ba","01"&x"c8","01"&x"da","01"&x"fd","10"&x"29","10"&x"7b","10"&x"e0",
	"10"&x"14","10"&x"14","10"&x"15","10"&x"15","10"&x"15","10"&x"16","10"&x"17","10"&x"18","10"&x"1b","10"&x"20","10"&x"2a","10"&x"37","10"&x"54","10"&x"7b","10"&x"c6","11"&x"25",
	"10"&x"9a","10"&x"9a","10"&x"9a","10"&x"9a","10"&x"9a","10"&x"9a","10"&x"9a","10"&x"9a","10"&x"9b","10"&x"9c","10"&x"a0","10"&x"a9","10"&x"c0","10"&x"e0","11"&x"25","11"&x"7a",
	"01"&x"66","01"&x"67","01"&x"68","01"&x"69","01"&x"6b","01"&x"6d","01"&x"71","01"&x"75","01"&x"7d","01"&x"87","01"&x"99","01"&x"af","01"&x"dc","10"&x"14","10"&x"79","10"&x"f3",
	"01"&x"67","01"&x"68","01"&x"6a","01"&x"6b","01"&x"6c","01"&x"6e","01"&x"72","01"&x"77","01"&x"7f","01"&x"88","01"&x"9a","01"&x"b0","01"&x"dc","10"&x"14","10"&x"79","10"&x"f3",
	"01"&x"68","01"&x"6a","01"&x"6b","01"&x"6c","01"&x"6e","01"&x"70","01"&x"73","01"&x"78","01"&x"7f","01"&x"89","01"&x"9b","01"&x"b1","01"&x"dd","10"&x"15","10"&x"79","10"&x"f3",
	"01"&x"69","01"&x"6b","01"&x"6c","01"&x"6d","01"&x"6f","01"&x"71","01"&x"74","01"&x"79","01"&x"80","01"&x"8a","01"&x"9c","01"&x"b1","01"&x"dd","10"&x"15","10"&x"79","10"&x"f3",
	"01"&x"6b","01"&x"6c","01"&x"6e","01"&x"6f","01"&x"70","01"&x"72","01"&x"76","01"&x"7a","01"&x"82","01"&x"8c","01"&x"9d","01"&x"b2","01"&x"de","10"&x"15","10"&x"79","10"&x"f3",
	"01"&x"6d","01"&x"6e","01"&x"70","01"&x"71","01"&x"72","01"&x"74","01"&x"78","01"&x"7c","01"&x"84","01"&x"8e","01"&x"9f","01"&x"b4","01"&x"df","10"&x"16","10"&x"79","10"&x"f3",
	"01"&x"71","01"&x"72","01"&x"73","01"&x"74","01"&x"76","01"&x"78","01"&x"7c","01"&x"80","01"&x"87","01"&x"91","01"&x"a1","01"&x"b6","01"&x"e0","10"&x"17","10"&x"79","10"&x"f3",
	"01"&x"75","01"&x"77","01"&x"78","01"&x"79","01"&x"7a","01"&x"7c","01"&x"80","01"&x"84","01"&x"8b","01"&x"94","01"&x"a4","01"&x"b9","01"&x"e3","10"&x"18","10"&x"79","10"&x"f3",
	"01"&x"7d","01"&x"7f","01"&x"7f","01"&x"80","01"&x"82","01"&x"84","01"&x"87","01"&x"8b","01"&x"92","01"&x"9b","01"&x"aa","01"&x"bf","01"&x"e7","10"&x"1b","10"&x"7a","10"&x"f3",
	"01"&x"87","01"&x"88","01"&x"89","01"&x"8a","01"&x"8c","01"&x"8e","01"&x"91","01"&x"94","01"&x"9b","01"&x"a2","01"&x"b2","01"&x"c6","01"&x"ed","10"&x"20","10"&x"7c","10"&x"f3",
	"01"&x"99","01"&x"9a","01"&x"9b","01"&x"9c","01"&x"9d","01"&x"9f","01"&x"a1","01"&x"a4","01"&x"aa","01"&x"b2","01"&x"c2","01"&x"d5","01"&x"fa","10"&x"2a","10"&x"82","10"&x"f5",
	"01"&x"af","01"&x"b0","01"&x"b1","01"&x"b1","01"&x"b2","01"&x"b4","01"&x"b6","01"&x"b9","01"&x"bf","01"&x"c6","01"&x"d5","01"&x"e7","10"&x"0b","10"&x"37","10"&x"8c","10"&x"f9",
	"01"&x"dc","01"&x"dc","01"&x"dd","01"&x"dd","01"&x"de","01"&x"df","01"&x"e0","01"&x"e3","01"&x"e7","01"&x"ed","01"&x"fa","10"&x"0b","10"&x"2c","10"&x"54","10"&x"a4","11"&x"09",
	"10"&x"14","10"&x"14","10"&x"15","10"&x"15","10"&x"15","10"&x"16","10"&x"17","10"&x"18","10"&x"1b","10"&x"20","10"&x"2a","10"&x"37","10"&x"54","10"&x"7b","10"&x"c6","11"&x"25",
	"10"&x"79","10"&x"79","10"&x"79","10"&x"79","10"&x"79","10"&x"79","10"&x"79","10"&x"79","10"&x"7a","10"&x"7c","10"&x"82","10"&x"8c","10"&x"a4","10"&x"c6","11"&x"0c","11"&x"62",
	"10"&x"f3","10"&x"f3","10"&x"f3","10"&x"f3","10"&x"f3","10"&x"f3","10"&x"f3","10"&x"f3","10"&x"f3","10"&x"f3","10"&x"f5","10"&x"f9","11"&x"09","11"&x"25","11"&x"62","11"&x"b1",
	"10"&x"1a","10"&x"1a","10"&x"1a","10"&x"1b","10"&x"1b","10"&x"1c","10"&x"1d","10"&x"1f","10"&x"22","10"&x"28","10"&x"34","10"&x"44","10"&x"69","10"&x"9a","10"&x"f3","11"&x"61",
	"10"&x"1a","10"&x"1b","10"&x"1b","10"&x"1b","10"&x"1b","10"&x"1c","10"&x"1d","10"&x"1f","10"&x"22","10"&x"28","10"&x"34","10"&x"44","10"&x"69","10"&x"9a","10"&x"f3","11"&x"61",
	"10"&x"1a","10"&x"1b","10"&x"1b","10"&x"1b","10"&x"1c","10"&x"1c","10"&x"1d","10"&x"1f","10"&x"23","10"&x"28","10"&x"34","10"&x"44","10"&x"69","10"&x"9a","10"&x"f3","11"&x"61",
	"10"&x"1b","10"&x"1b","10"&x"1b","10"&x"1c","10"&x"1c","10"&x"1c","10"&x"1e","10"&x"1f","10"&x"23","10"&x"29","10"&x"34","10"&x"44","10"&x"69","10"&x"9a","10"&x"f3","11"&x"61",
	"10"&x"1b","10"&x"1b","10"&x"1c","10"&x"1c","10"&x"1c","10"&x"1d","10"&x"1e","10"&x"20","10"&x"23","10"&x"29","10"&x"34","10"&x"44","10"&x"69","10"&x"9a","10"&x"f3","11"&x"61",
	"10"&x"1c","10"&x"1c","10"&x"1c","10"&x"1c","10"&x"1d","10"&x"1e","10"&x"1f","10"&x"20","10"&x"24","10"&x"29","10"&x"35","10"&x"44","10"&x"69","10"&x"9a","10"&x"f3","11"&x"61",
	"10"&x"1d","10"&x"1d","10"&x"1d","10"&x"1e","10"&x"1e","10"&x"1f","10"&x"20","10"&x"21","10"&x"25","10"&x"2a","10"&x"35","10"&x"45","10"&x"69","10"&x"9a","10"&x"f3","11"&x"61",
	"10"&x"1f","10"&x"1f","10"&x"1f","10"&x"1f","10"&x"20","10"&x"20","10"&x"21","10"&x"23","10"&x"26","10"&x"2c","10"&x"36","10"&x"46","10"&x"6a","10"&x"9a","10"&x"f3","11"&x"61",
	"10"&x"22","10"&x"22","10"&x"23","10"&x"23","10"&x"23","10"&x"24","10"&x"25","10"&x"26","10"&x"2a","10"&x"2f","10"&x"39","10"&x"48","10"&x"6b","10"&x"9b","10"&x"f3","11"&x"61",
	"10"&x"28","10"&x"28","10"&x"28","10"&x"29","10"&x"29","10"&x"29","10"&x"2a","10"&x"2c","10"&x"2f","10"&x"34","10"&x"3d","10"&x"4c","10"&x"6e","10"&x"9c","10"&x"f3","11"&x"61",
	"10"&x"34","10"&x"34","10"&x"34","10"&x"34","10"&x"34","10"&x"35","10"&x"35","10"&x"36","10"&x"39","10"&x"3d","10"&x"47","10"&x"55","10"&x"75","10"&x"a0","10"&x"f5","11"&x"61",
	"10"&x"44","10"&x"44","10"&x"44","10"&x"44","10"&x"44","10"&x"44","10"&x"45","10"&x"46","10"&x"48","10"&x"4c","10"&x"55","10"&x"63","10"&x"80","10"&x"a9","10"&x"f9","11"&x"61",
	"10"&x"69","10"&x"69","10"&x"69","10"&x"69","10"&x"69","10"&x"69","10"&x"69","10"&x"6a","10"&x"6b","10"&x"6e","10"&x"75","10"&x"80","10"&x"9b","10"&x"c0","11"&x"09","11"&x"67",
	"10"&x"9a","10"&x"9a","10"&x"9a","10"&x"9a","10"&x"9a","10"&x"9a","10"&x"9a","10"&x"9a","10"&x"9b","10"&x"9c","10"&x"a0","10"&x"a9","10"&x"c0","10"&x"e0","11"&x"25","11"&x"7a",
	"10"&x"f3","10"&x"f3","10"&x"f3","10"&x"f3","10"&x"f3","10"&x"f3","10"&x"f3","10"&x"f3","10"&x"f3","10"&x"f3","10"&x"f5","10"&x"f9","11"&x"09","11"&x"25","11"&x"62","11"&x"b1",
	"11"&x"61","11"&x"61","11"&x"61","11"&x"61","11"&x"61","11"&x"61","11"&x"61","11"&x"61","11"&x"61","11"&x"61","11"&x"61","11"&x"61","11"&x"67","11"&x"7a","11"&x"b1","11"&x"f9"
);

signal ROM : ROM_ARRAY := voltable;

begin

process(CLK)
begin
	if rising_edge(CLK) then
		DATA_A <= ROM(to_integer(unsigned(ADDR_A)));
		DATA_B <= ROM(to_integer(unsigned(ADDR_B)));
	end if;
end process;
end RTL;

