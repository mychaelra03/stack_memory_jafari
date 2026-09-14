library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity up_down_counter is
    generic (
        WIDTH : positive := 3
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;   -- reset hardware generale
        increment : in  std_logic;   -- +1
        decrement : in  std_logic;   -- -1
        clear     : in  std_logic;   -- azzera il contatore (funzionale)
        count     : out std_logic_vector(WIDTH-1 downto 0)
    );
end entity up_down_counter;

architecture structural of up_down_counter is

    component d_flip_flop is
        port (
            clk : in  std_logic;
            rst : in  std_logic;
            d   : in  std_logic;
            q   : out std_logic
        );
    end component;

    -- Valore corrente del contatore
    signal count_reg  : std_logic_vector(WIDTH-1 downto 0);

    -- Risultato dell'incremento (ripple carry adder con cin=1)
    signal inc_carry  : std_logic_vector(WIDTH downto 0);
    signal inc_result : std_logic_vector(WIDTH-1 downto 0);

    -- Risultato del decremento (ripple carry adder con valore "111...1" e cin=0)
    -- sp - 1 = sp + (2^WIDTH - 1), ovvero somma con tutti 1 e cin=0
    signal dec_carry  : std_logic_vector(WIDTH downto 0);
    signal dec_result : std_logic_vector(WIDTH-1 downto 0);

    -- Valore prossimo del contatore (mux tra inc/dec/clear/hold)
    signal count_next : std_logic_vector(WIDTH-1 downto 0);

begin

    -- ----------------------------------------------------------------
    -- Ripple-carry incrementer: count + 1
    -- Somma count con 0 e cin = 1
    -- ----------------------------------------------------------------
    inc_carry(0) <= '1';
    inc_ripple: for i in 0 to WIDTH-1 generate
        inc_result(i) <= count_reg(i) xor inc_carry(i);
        inc_carry(i+1) <= count_reg(i) and inc_carry(i);
    end generate inc_ripple;

    -- ----------------------------------------------------------------
    -- Ripple-carry decrementer: count - 1 = count + "111" con cin=0
    -- Somma count con 111...1 e cin = 0
    -- ----------------------------------------------------------------
    dec_carry(0) <= '0';
    dec_ripple: for i in 0 to WIDTH-1 generate
        dec_result(i) <= not(count_reg(i) xor dec_carry(i));
        dec_carry(i+1) <= (count_reg(i) or dec_carry(i));
    end generate dec_ripple;

    -- ----------------------------------------------------------------
    -- Mux next value: priorità clear > increment > decrement > hold
    -- ----------------------------------------------------------------
    next_value: process(count_reg, increment, decrement, clear,
                        inc_result, dec_result)
    begin
        if clear = '1' then
            count_next <= (others => '0');
        elsif increment = '1' then
            count_next <= inc_result;
        elsif decrement = '1' then
            count_next <= dec_result;
        else
            count_next <= count_reg;
        end if;
    end process next_value;

    -- ----------------------------------------------------------------
    -- Registro del contatore (WIDTH DFF)
    -- rst hardware resetta il registro; clear è solo logica combinatoria
    -- ----------------------------------------------------------------
    count_regs: for i in 0 to WIDTH-1 generate
        dff_i: d_flip_flop
            port map (
                clk => clk,
                rst => rst,
                d   => count_next(i),
                q   => count_reg(i)
            );
    end generate count_regs;

    count <= count_reg;

end architecture structural;
