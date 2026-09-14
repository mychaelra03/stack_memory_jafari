library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity register_bank is
    generic (
        WIDTH : positive := 8
    );
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        enable : in  std_logic;
        d      : in  std_logic_vector(WIDTH-1 downto 0);
        q      : out std_logic_vector(WIDTH-1 downto 0)
    );
end entity register_bank;

architecture structural of register_bank is

    component d_flip_flop is
        port (
            clk : in  std_logic;
            rst : in  std_logic;
            d   : in  std_logic;
            q   : out std_logic
        );
    end component;

    signal q_int   : std_logic_vector(WIDTH-1 downto 0);
    signal d_gated : std_logic_vector(WIDTH-1 downto 0);

begin

    -- Mux enable: se enable=0 il DFF si auto-alimenta (mantiene valore)
    enable_mux: for i in 0 to WIDTH-1 generate
        d_gated(i) <= d(i) when enable = '1' else q_int(i);
    end generate enable_mux;

    bit_array: for i in 0 to WIDTH-1 generate
        dff_i: d_flip_flop
            port map (
                clk => clk,
                rst => rst,
                d   => d_gated(i),
                q   => q_int(i)
            );
    end generate bit_array;

    q <= q_int;

end architecture structural;
