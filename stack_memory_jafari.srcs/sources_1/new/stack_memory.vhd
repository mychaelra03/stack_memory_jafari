library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity stack_memory is
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        din       : in  std_logic_vector(7 downto 0);
        push      : in  std_logic;
        pop       : in  std_logic;
        clear     : in  std_logic;
        dout      : out std_logic_vector(7 downto 0);
        isfull    : out std_logic;
        isempty   : out std_logic;
        pusherror : out std_logic;
        poperror  : out std_logic
    );
end entity stack_memory;

architecture structural of stack_memory is

    component d_flip_flop is
        port (clk : in std_logic; rst : in std_logic;
              d   : in std_logic; q   : out std_logic);
    end component;

    component register_bank is
        generic (WIDTH : positive := 8);
        port (clk    : in  std_logic; rst    : in  std_logic;
              enable : in  std_logic;
              d      : in  std_logic_vector(WIDTH-1 downto 0);
              q      : out std_logic_vector(WIDTH-1 downto 0));
    end component;

    component up_down_counter is
        generic (WIDTH : positive := 3);
        port (clk       : in  std_logic;
              rst       : in  std_logic;
              increment : in  std_logic;
              decrement : in  std_logic;
              clear     : in  std_logic;
              count     : out std_logic_vector(WIDTH-1 downto 0));
    end component;

    constant DEPTH     : positive := 8;
    constant DATA_BITS : positive := 8;
    constant ADDR_BITS : positive := 3;

    type data_array_t   is array (0 to DEPTH-1) of std_logic_vector(DATA_BITS-1 downto 0);
    type enable_array_t is array (0 to DEPTH-1) of std_logic;

    -- Ingressi registrati
    signal din_r   : std_logic_vector(DATA_BITS-1 downto 0);
    signal push_r  : std_logic;
    signal pop_r   : std_logic;
    signal clear_r : std_logic;

    -- Stack pointer
    signal sp : std_logic_vector(ADDR_BITS-1 downto 0);

    -- State flags: both REFISTERS, updated in the same process
    signal isfull_int  : std_logic;
    signal isempty_int : std_logic;

    -- Operations used to pilot sp and memory data
    signal do_push : std_logic;
    signal do_pop  : std_logic;

    -- Memory enable of every line, and memory's data
    signal mem_wr_en : enable_array_t;
    signal mem_q     : data_array_t;

    -- sp-1 for POP operations
    signal sp_minus1      : std_logic_vector(ADDR_BITS-1 downto 0);
    signal dec_carry_read : std_logic_vector(ADDR_BITS downto 0);

    -- Internal outputs before registers
    signal dout_int      : std_logic_vector(DATA_BITS-1 downto 0);
    signal pusherror_int : std_logic;
    signal poperror_int  : std_logic;

begin

    -- In registers
    reg_din: register_bank
        generic map (WIDTH => DATA_BITS)
        port map (clk => clk, rst => rst, enable => '1',
                  d => din, q => din_r);

    dff_push:  d_flip_flop port map (clk=>clk, rst=>rst, d=>push,  q=>push_r);
    dff_pop:   d_flip_flop port map (clk=>clk, rst=>rst, d=>pop,   q=>pop_r);
    dff_clear: d_flip_flop port map (clk=>clk, rst=>rst, d=>clear, q=>clear_r);

    -- ================================================================
    -- Convenzione sp:
    --   sp = number of elements in stack (0 = vuoto)
    --   isempty = (sp == 0)
    --   isfull  = (sp == 8), separated flag for 8, since 3 bits are not enough
    --
    -- Process reads SP after counter is updated
    -- (sp is already in value for current cycle)
    -- ================================================================
    flags_proc: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                isfull_int  <= '0';
                isempty_int <= '1';  -- after reset the stack is empty
            elsif clear_r = '1' then
                isfull_int  <= '0';
                isempty_int <= '1';  -- after clear the stack is empty
            else
                -- ISFULL: when SP is 7.
                -- sp goes from "111" to "000" (overflow).
                -- if SP = "111" and DO_PUSH = "1" then stack is full
                if push_r = '1' and isfull_int = '0' and sp = "111" then
                    isfull_int <= '1';
                elsif pop_r = '1' and isfull_int = '1' then
                    isfull_int <= '0';
                end if;

                -- ISEMPTY: when sp is "000".
                -- sp="001" and do_pop=1 -> next step: ISEMPTY
                -- sp="000" and do_push=1 -> next step: not empty anymore
                if pop_r = '1' and isempty_int = '0' and sp = "001" then
                    isempty_int <= '1';
                elsif push_r = '1' and isempty_int = '1' then
                    isempty_int <= '0';
                end if;
            end if;
        end if;
    end process flags_proc;

    -- Bock of operations when they are forbitten
    do_push <= push_r and (not isfull_int);
    do_pop  <= pop_r  and (not isempty_int);

    -- ================================================================
    -- STACK POINTER
    -- ================================================================
    sp_counter: up_down_counter
        generic map (WIDTH => ADDR_BITS)
        port map (
            clk       => clk,
            rst       => rst,
            increment => do_push,
            decrement => do_pop,
            clear     => clear_r,
            count     => sp -- sp gets modified
        );

    -- ================================================================
    -- sp_minus1 = SP-1 (top of stack for read operations)
    -- ================================================================
    dec_carry_read(0) <= '0';
    sp_dec: for i in 0 to ADDR_BITS-1 generate
        sp_minus1(i)        <= not (sp(i) xor dec_carry_read(i));
        dec_carry_read(i+1) <= (sp(i) or dec_carry_read(i));
    end generate sp_dec;

    -- ================================================================
    -- WRITE DECODER
    -- ================================================================
    write_decoder: process(do_push, sp)
    begin
        for i in 0 to DEPTH-1 loop -- i from 0 to 7
            mem_wr_en(i) <= '0';
        end loop;
        if do_push = '1' then
            case sp is
                when "000" => mem_wr_en(0) <= '1';
                when "001" => mem_wr_en(1) <= '1';
                when "010" => mem_wr_en(2) <= '1';
                when "011" => mem_wr_en(3) <= '1';
                when "100" => mem_wr_en(4) <= '1';
                when "101" => mem_wr_en(5) <= '1';
                when "110" => mem_wr_en(6) <= '1';
                when "111" => mem_wr_en(7) <= '1';
                when others => null;
            end case;
        end if;
    end process write_decoder;

    -- ================================================================
    -- MEMORY LINES
    -- ================================================================
    mem_gen: for i in 0 to DEPTH-1 generate
        mem_cell_i: register_bank
            generic map (WIDTH => DATA_BITS)
            port map (
                clk    => clk,
                rst    => rst,
                enable => mem_wr_en(i),
                d      => din_r,
                q      => mem_q(i)
            );
    end generate mem_gen;

    -- ================================================================
    -- READ MUX (do_pop = 1?)
    -- ================================================================
    read_mux: process(sp_minus1, mem_q)
    begin
        case sp_minus1 is
            when "000" => dout_int <= mem_q(0); -- dout_int = mem_q(i)
            when "001" => dout_int <= mem_q(1);
            when "010" => dout_int <= mem_q(2);
            when "011" => dout_int <= mem_q(3);
            when "100" => dout_int <= mem_q(4);
            when "101" => dout_int <= mem_q(5);
            when "110" => dout_int <= mem_q(6);
            when "111" => dout_int <= mem_q(7);
            when others => dout_int <= (others => '0');
        end case;
    end process read_mux;

    -- ================================================================
    -- ERROR SIGNALS
    -- ================================================================
    pusherror_int <= push_r and isfull_int;
    poperror_int  <= pop_r  and isempty_int;

    -- ================================================================
    -- OUT REGISTERS
    -- Register DOUT has ENABLE = DO_POP.
    -- Value is captured and stored till next POP .
    -- ================================================================
    reg_dout: register_bank
        generic map (WIDTH => DATA_BITS)
        port map (clk => clk, rst => rst,
                  enable => do_pop,   -- only after valid pop
                  d      => dout_int,
                  q      => dout);

    dff_isfull:    d_flip_flop port map (clk=>clk, rst=> rst, d=>isfull_int,    q=>isfull);
    --dff_isempty:   d_flip_flop port map (clk=>clk, rst=> '0', d=>isempty_int,   q=>isempty);
    dff_pusherror: d_flip_flop port map (clk=>clk, rst=> rst, d=>pusherror_int, q=>pusherror);
    dff_poperror:  d_flip_flop port map (clk=>clk, rst=> rst, d=>poperror_int,  q=>poperror);
    
    isempty_out: process(clk, rst)
    begin
        if rst = '1' then
            isempty <= '1';       -- preset: parte a 1
        elsif rising_edge(clk) then
            isempty <= isempty_int;
        end if;
    end process isempty_out;

end architecture structural;
