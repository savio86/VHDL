----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:05:53 02/01/2016 
-- Design Name: 
-- Module Name:    PMBus - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_unsigned.all;
-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity PMBus is
    Port ( clk : in  STD_LOGIC;
           reset : in  STD_LOGIC;
		   start : in STD_LOGIC;
           sda : inout  STD_LOGIC;
           scl : inout  STD_LOGIC;
           address : in  STD_LOGIC_VECTOR (6 downto 0);
			  read_write :in STD_LOGIC; --'1' is write, '0' is read
		     command : in  STD_LOGIC_VECTOR (7 downto 0);
			  data_write : in  STD_LOGIC_VECTOR (15 downto 0);
           data_read : out  STD_LOGIC_VECTOR (15 downto 0));
end PMBus;

architecture Behavioral of PMBus is
  
  	component i2c_master 
  GENERIC(
    input_clk : INTEGER := 100_000_000; --input clock speed from user logic in Hz
    bus_clk   : INTEGER := 400_000);   --speed the i2c bus (scl) will run at in Hz
  PORT(
    clk       : IN     STD_LOGIC;                    --system clock
    reset_n   : IN     STD_LOGIC;                    --active low reset
    ena       : IN     STD_LOGIC;                    --latch in command
    addr      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); --address of target slave
    rw        : IN     STD_LOGIC;                    --'0' is write, '1' is read
    data_wr   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); --data to write to slave
    busy      : OUT    STD_LOGIC;                    --indicates transaction in progress
    data_rd   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
    ack_error : BUFFER STD_LOGIC;                    --flag if improper acknowledge from slave
    sda       : INOUT  STD_LOGIC;                    --serial data output of i2c bus
    scl       : INOUT  STD_LOGIC);                  --serial clock output of i2c bus
	
	end component;
	type 	 state_type	is (wait_start, write_command_1, latch_cmd_1, latch_cmd_2, copy_data_1, latch_cmd_3, copy_data_2, write_byte_1, write_byte_2);
	signal current_state : state_type;
	signal next_state	: state_type;
	signal start_i 	: std_logic;
	signal i2c_ena 	: std_logic;
	signal i2c_addr 	: std_logic_vector (6 downto 0);
	signal i2c_rw	 	: std_logic;
	signal i2c_data_wr 	: std_logic_vector (7 downto 0);
	signal i2c_busy	: std_logic;
	signal i2c_busy_delay	: std_logic;
	signal i2c_data_rd 	: std_logic_vector (7 downto 0);
	signal i2c_ack_error	: std_logic;
	signal i2c_busy_rising_pulse 	: std_logic;
	signal start_counter 	: std_logic;
	signal counter		: std_logic_vector (7 downto 0);
	signal FSM_status : std_logic_vector (2 downto 0);
	signal rw_excep : std_logic;
	

begin

sda <=sda ;
scl <=scl ;


process(clk)
 begin
	if (clk'event and clk='1') then
		if (reset ='1') then
			i2c_busy_delay<= '0';
		else 
			i2c_busy_delay <= i2c_busy;
		end if;
	end if;
 end process;
  
 i2c_busy_rising_pulse <= '1' when ((i2c_busy = '1')and (i2c_busy_delay='0')) else '0';
 

 sync_FSM: process(clk)
 begin
	if (clk'event and clk='1') then
		if (reset ='1') then
			current_state<= wait_start;
		else
			current_state<= next_state;
		end if;
	end if;
 end process sync_FSM;
 
 

 
 
 next_state_decode :process (current_state, start,i2c_busy,i2c_busy_rising_pulse,read_write)
 begin
 
 next_state <= current_state;
  case (current_state) is
         when wait_start =>
				if (start ='1') then
					 next_state <=write_command_1;
				end if;
			when write_command_1 =>								
				if (i2c_busy_rising_pulse='1')then
					if (read_write ='1') then
						next_state <=write_byte_1;
					else
						next_state <=latch_cmd_1;
					end if;
				end if;
			when latch_cmd_1 =>									
				if (i2c_busy_rising_pulse='1')then
					next_state <=latch_cmd_2;
				end if;
			when latch_cmd_2 =>
				if (i2c_busy='0')then
					next_state <=copy_data_1;
				end if;
			when copy_data_1 =>
				if (i2c_busy='1')then
					next_state <=latch_cmd_3;
				end if;
			when latch_cmd_3 =>
				if (i2c_busy='0')then
					next_state <=copy_data_2;
				end if;
			when copy_data_2 =>
					next_state <=wait_start;

			when write_byte_1 =>
			if (i2c_busy_rising_pulse='1')then
				next_state <=write_byte_2;
			end if;
			when write_byte_2 =>
			if (i2c_busy='0')then
				next_state <=wait_start;
			end if;			
			when others =>
            next_state <= wait_start;
	end case;
 end process next_state_decode;
 
 

	
	

 OUTPUT_DECODE: process (current_state, address, command,i2c_data_rd)
   begin
	  case (current_state) is
         when wait_start =>
				i2c_ena <= '0';
				i2c_addr<= "0000000" ;
				i2c_rw<= '1' ;
				i2c_data_wr<= x"00" ; 
				start_counter<='0';
				FSM_status <= "000";
				
			when write_command_1 =>					---write cmd 1---
				i2c_ena <= '1';
				i2c_addr<= address;
				i2c_rw<= '0' ;
				i2c_data_wr<= command ; 
				FSM_status <="001";
				
			when latch_cmd_1 =>						---write cmd 2, latch cmd 1---
				i2c_ena <= '1';
				i2c_addr<= address;
				i2c_rw<='1';				 
				i2c_data_wr<=x"00" ; 
				FSM_status <= "010";
				
			when latch_cmd_2 =>						  --write cmd 3, latch cmd 2---
				i2c_ena <= '1';
				i2c_addr<= address;
				i2c_rw<= '1' ;
				i2c_data_wr<= x"00" ; 
				FSM_status <= "011";
				
			when copy_data_1 =>						    --copy_data byte 1 from bus----
				i2c_ena <= '1';
				data_read(7 downto 0)<=i2c_data_rd;
				i2c_addr<= address;
				i2c_rw<= '1' ;
				i2c_data_wr<= x"00" ; 
				FSM_status <= "100";
				
			when latch_cmd_3 =>						      ---latch cmd 3 and exit---
				i2c_addr<= address;
				i2c_rw<= '1' ;
				i2c_data_wr<= x"00" ; 
				FSM_status <= "101";
				i2c_ena <= '0';
				
			when copy_data_2 =>								---copy_data byte 1 from bus----
				data_read(15 downto 8)<=i2c_data_rd;
				i2c_addr<= address;
				i2c_rw<= '1' ;
				i2c_data_wr<= x"00" ; 
				FSM_status <= "110";
				i2c_ena <= '0';
				
			when write_byte_1 =>
				i2c_ena <= '1';
				i2c_addr<= address;
				i2c_rw<= not(read_write); 
				i2c_data_wr<= data_write(7 downto 0); 
				FSM_status <= "111";

			when write_byte_2 =>
				i2c_ena <= '1';
				i2c_addr<= address;
				i2c_rw<= not(read_write);
				i2c_data_wr<= data_write(15 downto 8); 
				FSM_status <= "111";
				
			when others =>
            i2c_ena <= '0';
				i2c_addr<= "0000000" ;
				i2c_rw<= '1' ;
				i2c_data_wr<= x"00" ; 
			   start_counter<='0';
				FSM_status <= "111";
	end case;
   end process;
 
 
 
	i2c_master_i: i2c_master
	port map
	(
	 clk       => clk,                 	--system clock
    reset_n   => not(RESET),                 	--active low reset
    ena       => i2c_ena,             	--latch in command
    addr      => i2c_addr, 				--address of target slave
    rw        => i2c_rw,               --'0' is write, '1' is read
    data_wr   => i2c_data_wr,				--data to write to slave
    busy      => i2c_busy,             --indicates transaction in progress
    data_rd   => i2c_data_rd,				--data read from slave
    ack_error => i2c_ack_error,        --flag if improper acknowledge from slave
    sda       => SDA,                  --serial data output of i2c bus
    scl       => SCL 
	);
	
	
	

end Behavioral;

