-- Copyright (c) 2007-2020 Vitaly Chipounov
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

--------------------------------------------------
--Generic multiplier component
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library lpm;
use lpm.all;

--Easy to use: the result is twice the operand width
entity mult1 is
    generic (operand_width : natural);
    port (
        dataa : in STD_LOGIC_VECTOR (operand_width - 1 downto 0);
        datab : in STD_LOGIC_VECTOR (operand_width - 1 downto 0);
        result : out STD_LOGIC_VECTOR (operand_width * 2 - 1 downto 0)
    );
end mult1;
architecture SYN of mult1 is

    signal sub_wire0 : STD_LOGIC_VECTOR (operand_width * 2 - 1 downto 0);
    component lpm_mult
        generic (
            lpm_hint : string;
            lpm_representation : string;
            lpm_type : string;
            lpm_widtha : natural;
            lpm_widthb : natural;
            lpm_widthp : natural;
            lpm_widths : natural
        );
        port (
            dataa : in STD_LOGIC_VECTOR (operand_width - 1 downto 0);
            datab : in STD_LOGIC_VECTOR (operand_width - 1 downto 0);
            result : out STD_LOGIC_VECTOR (operand_width * 2 - 1 downto 0)
        );
    end component;

begin
    result <= sub_wire0(operand_width * 2 - 1 downto 0);

    lpm_mult_component : lpm_mult
    generic map(
        lpm_hint => "MAXIMIZE_SPEED=5",
        lpm_representation => "UNSIGNED",
        lpm_type => "LPM_MULT",
        lpm_widtha => operand_width,
        lpm_widthb => operand_width,
        lpm_widthp => operand_width * 2,
        lpm_widths => 1
    )
    port map(
        dataa => dataa,
        datab => datab,
        result => sub_wire0
    );

end SYN;