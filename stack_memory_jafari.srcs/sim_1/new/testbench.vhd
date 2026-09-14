library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity stack_memory_tb is
end entity stack_memory_tb;

architecture testbench of stack_memory_tb is

    component stack_memory is
        port (
            clk : in std_logic; rst : in std_logic;
            din : in std_logic_vector(7 downto 0);
            push : in std_logic; pop : in std_logic; clear : in std_logic;
            dout      : out std_logic_vector(7 downto 0);
            isfull    : out std_logic; isempty   : out std_logic;
            pusherror : out std_logic; poperror  : out std_logic
        );
    end component;

    -- Clock period decided with: T_min = T_constraint - WNS
    constant CLK_PERIOD : time := 10 ns; -- 10ns - 6,821ns = 3,179ns

    -- Latency: 1 cycle for in register + 1 cycle for out registers = 2 cycles
    -- 3 cycles for safety
    constant SETTLE : time := CLK_PERIOD * 3;

    signal clk       : std_logic := '0';
    signal rst       : std_logic := '1';
    signal din       : std_logic_vector(7 downto 0) := (others => '0');
    signal push      : std_logic := '0';
    signal pop       : std_logic := '0';
    signal clear     : std_logic := '0';
    signal dout      : std_logic_vector(7 downto 0);
    signal isfull    : std_logic;
    signal isempty   : std_logic;
    signal pusherror : std_logic;
    signal poperror  : std_logic;

begin

    dut: stack_memory
        port map (clk=>clk, rst=>rst, din=>din, push=>push, pop=>pop,
                  clear=>clear, dout=>dout, isfull=>isfull, isempty=>isempty,
                  pusherror=>pusherror, poperror=>poperror);

    clk_proc: process -- clk change
    begin
        clk <= '0'; wait for CLK_PERIOD/2;
        clk <= '1'; wait for CLK_PERIOD/2;
    end process;

    stimulus: process
    begin
        -- aspetto che il GSR di Vivado finisca
        wait for 100 ns;
    
        -- Initial RESET
        rst  <= '1';
        wait for CLK_PERIOD * 4;
        rst  <= '0';
        wait for SETTLE;
        -- Result: isempty=1, isfull=0

        -- ============================================================
        -- TEST 1: POP on empty stack
        -- ============================================================
        pop <= '1'; wait for CLK_PERIOD; pop <= '0';
        wait for SETTLE;
        -- Result: poperror=1 for 1 cycle, then returns to 0

        -- ============================================================
        -- TEST 2: PUSH with 8 elements (stack full)
        -- ============================================================
        din <= x"AA"; push <= '1'; wait for CLK_PERIOD; push <= '0'; wait for SETTLE;
        din <= x"55"; push <= '1'; wait for CLK_PERIOD; push <= '0'; wait for SETTLE;
        din <= x"FF"; push <= '1'; wait for CLK_PERIOD; push <= '0'; wait for SETTLE;
        din <= x"00"; push <= '1'; wait for CLK_PERIOD; push <= '0'; wait for SETTLE;
        din <= x"F0"; push <= '1'; wait for CLK_PERIOD; push <= '0'; wait for SETTLE;
        din <= x"0F"; push <= '1'; wait for CLK_PERIOD; push <= '0'; wait for SETTLE;
        din <= x"A5"; push <= '1'; wait for CLK_PERIOD; push <= '0'; wait for SETTLE;
        din <= x"5A"; push <= '1'; wait for CLK_PERIOD; push <= '0'; wait for SETTLE;
        -- Result: isfull=1, isempty=0

        -- ============================================================
        -- TEST 3: PUSH with full stack -> pusherror for 1 cycle
        -- ============================================================
        din <= x"FF"; push <= '1'; wait for CLK_PERIOD; push <= '0';
        wait for SETTLE;
        -- Result: pusherror=1 for 1 cycle, same stack

        -- ============================================================
        -- TEST 4: complete POP (verifying test 3 LIFO)
        -- Result on DOUT (2 cycle latency):
        --   5A ? A5 ? 0F ? F0 ? 00 ? FF ? 55 ? AA
        -- ============================================================
        pop <= '1'; wait for CLK_PERIOD; pop <= '0'; wait for SETTLE;
        pop <= '1'; wait for CLK_PERIOD; pop <= '0'; wait for SETTLE;
        pop <= '1'; wait for CLK_PERIOD; pop <= '0'; wait for SETTLE;
        pop <= '1'; wait for CLK_PERIOD; pop <= '0'; wait for SETTLE;
        pop <= '1'; wait for CLK_PERIOD; pop <= '0'; wait for SETTLE;
        pop <= '1'; wait for CLK_PERIOD; pop <= '0'; wait for SETTLE;
        pop <= '1'; wait for CLK_PERIOD; pop <= '0'; wait for SETTLE;
        pop <= '1'; wait for CLK_PERIOD; pop <= '0'; wait for SETTLE;
        -- Result: isempty=1, isfull=0

        -- ============================================================
        -- TEST 5: Partial PUSH and then CLEAR (NON usa rst)
        -- ============================================================
        din <= x"11"; push <= '1'; wait for CLK_PERIOD; push <= '0'; wait for SETTLE;
        din <= x"22"; push <= '1'; wait for CLK_PERIOD; push <= '0'; wait for SETTLE;
        din <= x"33"; push <= '1'; wait for CLK_PERIOD; push <= '0'; wait for SETTLE;
        -- Result: 3 elements, isempty=0, isfull=0
        clear <= '1'; wait for CLK_PERIOD; clear <= '0';
        wait for SETTLE;
        -- Result: isempty=1, isfull=0, sp=0

        -- ============================================================
        -- TEST 6: push/pop sequence (stress critical path)
        -- ============================================================
        din <= x"AA"; push <= '1'; wait for CLK_PERIOD; push <= '0'; wait for SETTLE;
        din <= x"BB"; push <= '1'; wait for CLK_PERIOD; push <= '0'; wait for SETTLE;
        pop  <= '1';               wait for CLK_PERIOD; pop  <= '0'; wait for SETTLE;
        din <= x"CC"; push <= '1'; wait for CLK_PERIOD; push <= '0'; wait for SETTLE;
        pop  <= '1';               wait for CLK_PERIOD; pop  <= '0'; wait for SETTLE;
        pop  <= '1';               wait for CLK_PERIOD; pop  <= '0'; wait for SETTLE;
        -- Result last DOUT: AA, isempty=1
        wait for SETTLE;

        wait;
    end process stimulus;

end architecture testbench;