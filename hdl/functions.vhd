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
-- Various utility functions
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package functions is
    function log2(input : natural) return natural;
    function vectorize(s : std_logic) return std_logic_vector;
    function delay2cycles(clock_speed : natural; delay : time) return natural;
end functions;

package body functions is
    --Take the base 2 logarithm of the specified integer.
    --It is very useful to compute the length of
    --signal vectors automatically.
    function log2(input : natural) return natural is
        variable temp, log : natural;
    begin
        if (input = 0) then
            return 0;
        end if;

        temp := input - 1;
        log := 0;
        while (temp /= 0) loop
            temp := temp/2;
            log := log + 1;
        end loop;
        return log;
    end function log2;

    function CEIL (X : real) return real is
        -- returns smallest integer value (as real) not less than X
        -- No conversion to an integer type is expected, so truncate cannot 
        -- overflow for large arguments.

        variable large : real := 1073741824.0;
        type long is range -1073741824 to 1073741824;
        -- 2**30 is longer than any single-precision mantissa
        variable rd : real;

    begin
        if abs(X) >= large then
            return X;
        else
            rd := real (long(X));
            if X > 0.0 then
                if rd >= X then
                    return rd;
                else
                    return rd + 1.0;
                end if;
            elsif X = 0.0 then
                return 0.0;
            else
                if rd <= X then
                    return rd;
                else
                    return rd - 1.0;
                end if;
            end if;
        end if;
    end CEIL;

    function FLOOR (X : real) return real is
        -- returns largest integer value (as real) not greater than X
        -- No conversion to an integer type is expected, so truncate 
        -- cannot overflow for large arguments.
        -- 
        variable large : real := 1073741824.0;
        type long is range -1073741824 to 1073741824;
        -- 2**30 is longer than any single-precision mantissa
        variable rd : real;

    begin
        if abs(X) >= large then
            return X;
        else
            rd := real (long(X));
            if X > 0.0 then
                if rd <= X then
                    return rd;
                else
                    return rd - 1.0;
                end if;
            elsif X = 0.0 then
                return 0.0;
            else
                if rd >= X then
                    return rd;
                else
                    return rd + 1.0;
                end if;
            end if;
        end if;
    end FLOOR;

    function ROUND (X : real) return real is
        -- returns integer FLOOR(X + 0.5) if X > 0;
        -- return integer CEIL(X - 0.5) if X < 0
    begin
        if X > 0.0 then
            return FLOOR(X + 0.5);
        elsif X < 0.0 then
            return CEIL(X - 0.5);
        else
            return 0.0;
        end if;
    end ROUND;

    function delay2cycles(clock_speed : natural; delay : time) return natural is
        variable v : real;
        variable r : natural;
    begin
        v := real(1.0/real(1 sec / delay)) / (1.0/real(clock_speed));
        report("time is " & time'image(delay)
            & " - " & real'image(1.0/real(1 sec / delay))
            & " - cycle is " & real'image(1.0/real(clock_speed))
            & " - v is " & real'image(v) & " - round is " & real'image(round(v)));
        r := natural(round(v));
        if (r = 0) then
            return 1;
        else
            return r;
        end if;
    end;

    function vectorize(s : std_logic) return std_logic_vector is
        variable v : std_logic_vector(0 downto 0);
    begin
        v(0) := s;
        return v;
    end;
end functions;