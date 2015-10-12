------------------------------------------------------------------------------
-- axi_stream_generator - entity/architecture pair
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 1995-2012 Xilinx, Inc.  All rights reserved.            **
-- **                                                                       **
-- ** Xilinx, Inc.                                                          **
-- ** XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS"         **
-- ** AS A COURTESY TO YOU, SOLELY FOR USE IN DEVELOPING PROGRAMS AND       **
-- ** SOLUTIONS FOR XILINX DEVICES.  BY PROVIDING THIS DESIGN, CODE,        **
-- ** OR INFORMATION AS ONE POSSIBLE IMPLEMENTATION OF THIS FEATURE,        **
-- ** APPLICATION OR STANDARD, XILINX IS MAKING NO REPRESENTATION           **
-- ** THAT THIS IMPLEMENTATION IS FREE FROM ANY CLAIMS OF INFRINGEMENT,     **
-- ** AND YOU ARE RESPONSIBLE FOR OBTAINING ANY RIGHTS YOU MAY REQUIRE      **
-- ** FOR YOUR IMPLEMENTATION.  XILINX EXPRESSLY DISCLAIMS ANY              **
-- ** WARRANTY WHATSOEVER WITH RESPECT TO THE ADEQUACY OF THE               **
-- ** IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OR        **
-- ** REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE FROM CLAIMS OF       **
-- ** INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS       **
-- ** FOR A PARTICULAR PURPOSE.                                             **
-- **                                                                       **
-- ***************************************************************************
--
------------------------------------------------------------------------------
-- Filename:          axi_stream_generator
-- Version:           1.00.a
-- Description:       Example Axi Streaming core (VHDL).
-- Date:              Tue Nov 19 10:13:17 2013 (by Create and Import Peripheral Wizard)
-- VHDL Standard:     VHDL'93
------------------------------------------------------------------------------
-- Naming Conventions:
--   active low signals:                    "*_n"
--   clock signals:                         "clk", "clk_div#", "clk_#x"
--   reset signals:                         "rst", "rst_n"
--   generics:                              "C_*"
--   user defined types:                    "*_TYPE"
--   state machine next state:              "*_ns"
--   state machine current state:           "*_cs"
--   combinatorial signals:                 "*_com"
--   pipelined or register delay signals:   "*_d#"
--   counter signals:                       "*cnt*"
--   clock enable signals:                  "*_ce"
--   internal version of output port:       "*_i"
--   device pins:                           "*_pin"
--   ports:                                 "- Names begin with Uppercase"
--   processes:                             "*_PROCESS"
--   component instantiations:              "<ENTITY_>I_<#|FUNC>"
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-------------------------------------------------------------------------------------
--
--
-- Definition of Ports
-- ACLK              : Synchronous clock
-- ARESETN           : System reset, active low
-- S_AXIS_TREADY  : Ready to accept data in
-- S_AXIS_TDATA   :  Data in 
-- S_AXIS_TLAST   : Optional data in qualifier
-- S_AXIS_TVALID  : Data in is valid
-- M_AXIS_TVALID  :  Data out is valid
-- M_AXIS_TDATA   : Data Out
-- M_AXIS_TLAST   : Optional data out qualifier
-- M_AXIS_TREADY  : Connected slave device is ready to accept data out
--
-------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Entity Section
------------------------------------------------------------------------------

entity axi_stream_generator is
	port 
	(
		-- DO NOT EDIT BELOW THIS LINE ---------------------
		GPIO_I	: in	std_logic_vector(31 downto 0);
		GPIO_O	: out	std_logic_vector(31 downto 0);
		-- Bus protocol ports, do not add or delete. 
		ACLK	: in	std_logic;
		ARESETN	: in	std_logic;
		S_AXIS_TREADY	: out	std_logic;
		S_AXIS_TDATA	: in	std_logic_vector(31 downto 0);
		S_AXIS_TLAST	: in	std_logic;
		S_AXIS_TVALID	: in	std_logic;
		M_AXIS_TVALID	: out	std_logic;
		M_AXIS_TDATA	: out	std_logic_vector(31 downto 0);
		M_AXIS_TLAST	: out	std_logic;
		M_AXIS_TREADY	: in	std_logic
		-- DO NOT EDIT ABOVE THIS LINE ---------------------
	);

attribute SIGIS : string; 
attribute SIGIS of ACLK : signal is "Clk"; 

end axi_stream_generator;

------------------------------------------------------------------------------
-- Architecture Section
------------------------------------------------------------------------------

-- In this section, we povide an example implementation of ENTITY axi_stream_generator
-- that does the following:
--
-- 1. Read all inputs
-- 2. Add each input to the contents of register 'sum' which
--    acts as an accumulator
-- 3. After all the inputs have been read, write out the
--    content of 'sum' into the output stream NUMBER_OF_OUTPUT_WORDS times
--
-- You will need to modify this example or implement a new architecture for
-- ENTITY axi_stream_generator to implement your coprocessor

architecture EXAMPLE of axi_stream_generator is
	component icap_controller
	PORT (
		i_clk 			: IN STD_LOGIC;
		i_rst 			: IN STD_LOGIC;
		rst_ibuff		: IN STD_LOGIC;
		i_ibuff_data 	: IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- Config data Proc to FIFO (input buffer)
		wr_en_ibuff		: IN STD_LOGIC;
		rd_en_obuff		: IN STD_LOGIC;
		i_icap_rd_en	: IN STD_LOGIC;	-- Request from Proc to read or write the config data, 1 - read, 
		i_icap_wr_en	: IN STD_LOGIC; -- Request from Proc to read or write the config data, 1 - write, 
		i_micap_en		: IN STD_LOGIC; -- MiCAP enable signal, to be set only after writing the data in FIFO
		wait_en			: IN STD_LOGIC; --wait untill the ibuff is filled

		o_config_buff_full	: OUT STD_LOGIC;
		o_icap_en			: OUT STD_LOGIC;
		o_icap_data			: OUT STD_LOGIC_VECTOR(31 DOWNTO 0); -- Config data from FIFO (output buffer) to Proc
		o_icap_wr_rd_done	: OUT STD_LOGIC; -- Flag to indicate ICAP rd/wr done
		empty_ibuff			: OUT STD_LOGIC;
		o_icap_waiting		: OUT STD_LOGIC;
		empty_obuff			: OUT STD_LOGIC
		);
	END component;
		
   -- Total number of input data.
   constant wrFrame_NUMBER_OF_INPUT_WORDS  : natural := 540;
   constant rdFrame_NUMBER_OF_INPUT_WORDS  : natural := 57;

   -- Total number of output data
   --constant wrFrame_NUMBER_OF_OUTPUT_WORDS : natural := 540;
   constant rdFrame_NUMBER_OF_OUTPUT_WORDS : natural := 506;

   type STATE_TYPE is (Idle, 
					   reset,
					   wrFrame_idle,
					   wrFrame_in,
					   trigger_read,
					   trigger_write,
					   wrFrame_wait,
					   rdFrame_wait,
					   rdFrame_idle,
					   rdFrame_in,
					   rdFrame_out					   
					);

   signal state        : STATE_TYPE;

	-- Register related signals
	signal	wr_control: std_logic; 
	signal	rd_control: std_logic; 
	signal	stream_busy: std_logic;
	signal	str_buffer_rd_done: std_logic;
	signal	str_buffer_wr_done: std_logic;

	-- FIFO related signals
	signal buffer_reset : std_logic; 
	signal wr_en 		: std_logic; 
	signal rd_en 		: std_logic; 
	signal dout 		: std_logic_vector(31 downto 0);
	signal full  		: std_logic;
	signal empty 		: std_logic;
	
	-- MiCAP related signals		
	signal micap_rd_en : std_logic;
	signal micap_wr_en : std_logic;
	signal micap_en : std_logic;
	signal micap_wait_en : std_logic;
	signal micap_waiting : std_logic;
	signal micap_reset : std_logic;
	signal micap_rd_wr_done : std_logic;
	signal buffer_full : std_logic;
	signal micap_en_o : std_logic;
	signal empty_ibuff : std_logic;
	signal empty_obuff : std_logic;


	signal micap_read_done : std_logic;
	signal micap_write_done : std_logic;
	signal micap_wait : std_logic;
		
   -- Accumulator to hold inputs read at any point in time
   signal sum          : std_logic_vector(31 downto 0);

   -- Counters to store the number inputs read & outputs written
   signal wrFrame_nr_of_reads  : natural range 0 to wrFrame_NUMBER_OF_INPUT_WORDS - 1;
   signal rdFrame_nr_of_reads  : natural range 0 to rdFrame_NUMBER_OF_INPUT_WORDS - 1;
   
  -- signal wrFrame_nr_of_writes : natural range 0 to wrFrame_NUMBER_OF_OUTPUT_WORDS - 1;   
   signal rdFrame_nr_of_writes : natural range 0 to rdFrame_NUMBER_OF_OUTPUT_WORDS - 1;
   
   -- TLAST signal
   signal tlast : std_logic;
   signal dummy : std_logic;
begin

   M_AXIS_TDATA <= dout;
   M_AXIS_TLAST <= tlast;

	wr_control <= GPIO_I(1);
	rd_control <= GPIO_I(2);
	
	GPIO_O(0) <= micap_read_done;
	GPIO_O(1) <= micap_write_done;
	GPIO_O(2) <= micap_wait;
	GPIO_O(3) <= dummy;
	GPIO_O(8) <= tlast;
	GPIO_O(9) <= empty_obuff;
	GPIO_O(10) <= empty_ibuff;

	GPIO_O(31 downto 11) <= (OTHERS => '0');
	
--GPIO_I pins mapping
--	GPIO_I (0) => software ready
--	GPIO_I (1) => wr_control
--	GPIO_I (2) => rd_control
--	GPIO_I (4) => write_done_detected

--GPIO_O pins mapping
--	GPIO_O (0) => micap_read_done
--	GPIO_O (1) => micap_write_done
	
   The_SW_accelerator : process (ACLK) is
   begin  -- process The_SW_accelerator
    if ACLK'event and ACLK = '1' then     -- Rising clock edge
      if (ARESETN = '0') then               -- Synchronous reset (active low)
        state        <= Idle;
        sum          <= (others => '0');
        tlast        <= '0';
		M_AXIS_TVALID <= '0';
        S_AXIS_TREADY  <= '0';
        wrFrame_nr_of_reads <= 0;
		rdFrame_nr_of_reads <= 0;
		rdFrame_nr_of_writes <= 0; 
		buffer_reset <= '1';
		M_AXIS_TVALID <= '0';
		S_AXIS_TREADY <= '0';
		micap_rd_en <= '0';
		micap_wr_en <= '0';
		micap_en <= '0';
		micap_wait_en <= '0';
		micap_reset <= '1';
		micap_read_done <= '0';
		micap_write_done <= '0';
		micap_wait <= '0';
		dummy <= '0';
      else
      
        case state is
          when reset =>
          GPIO_O(7 downto 4) <= "0000";
			state        <= Idle;
			sum          <= (others => '0');
			tlast        <= '0';
			M_AXIS_TVALID <= '0';
			S_AXIS_TREADY  <= '0';
			wrFrame_nr_of_reads <= 0;
			rdFrame_nr_of_reads <= 0;
			rdFrame_nr_of_writes <= 0;   
			wr_en <= '0';
			rd_en <= '0';	
			buffer_reset <= '1';
			micap_rd_en <= '0';
			micap_wr_en <= '0';
			micap_en <= '0';
			micap_wait_en <= '1';
			micap_reset <= '0';	
			micap_read_done <= '0';
			micap_write_done <= '0';
			micap_wait <= '0';
			dummy<='0';	     
			
          when Idle =>
          GPIO_O(7 downto 4) <= "0001";          
			micap_rd_en <= '0';
			micap_wr_en <= '0';
			micap_en <= '0';
			micap_wait_en <= '1';
			micap_reset <= '0';
			tlast <= '0';
			S_AXIS_TREADY <= '0';	
			M_AXIS_TVALID <= '0';
			buffer_reset <= '0';
			micap_wait <= '0';
			dummy <= '1';
			
			if (micap_waiting = '1') then
				micap_wait <= '1';
			elsif (micap_waiting = '0') then
				micap_wait <= '0';
			end if;
			
			if (wr_control = '0' and rd_control = '0') then
				state  <= Idle;	
			elsif (wr_control = '1' and rd_control = '0') then
				state  <= wrFrame_idle;
				wrFrame_nr_of_reads <= wrFrame_NUMBER_OF_INPUT_WORDS - 1;
			elsif (wr_control = '0' and rd_control = '1') then
				state  <= rdFrame_idle;
				rdFrame_nr_of_reads <= rdFrame_NUMBER_OF_INPUT_WORDS - 1;
				rdFrame_nr_of_writes <= rdFrame_NUMBER_OF_OUTPUT_WORDS - 1;
			end if;

          when wrFrame_idle =>
          GPIO_O(7 downto 4) <= "0010";                    
			M_AXIS_TVALID <= '0';
			micap_rd_en <= '0';
			micap_wr_en <= '0';
			micap_en <= '0';
			micap_wait_en <= '1';
			if (micap_waiting = '1') then
				state <= wrFrame_in;
				micap_wait <= '1';
			end if;
          
          when wrFrame_in => 
          GPIO_O(7 downto 4) <= "0011";                    
          	if(GPIO_I(0) = '1') then 
				S_AXIS_TREADY <= '1';
				if (S_AXIS_TVALID = '1') then
				  wr_en <= '1';
				  sum  <= std_logic_vector(unsigned(S_AXIS_TDATA));
				  if (wrFrame_nr_of_reads = 0) then
					state <= trigger_write;
					wr_en <= '0';
					micap_wait <= '0';         
				  else
					wrFrame_nr_of_reads <= wrFrame_nr_of_reads - 1;
				  end if;
				end if;
			end if;

          when trigger_write => 
          GPIO_O(7 downto 4) <= "0100";                                 
			micap_rd_en <= '0';
			micap_wr_en <= '1';
			micap_en <= '1';
			micap_wait_en <= '0';
			state <= wrFrame_wait;

          when wrFrame_wait => --micap done
          GPIO_O(7 downto 4) <= "0101";                                           
			if(micap_rd_wr_done = '1') then 
				micap_write_done <= '1';
				micap_rd_en <= '0';
				micap_wr_en <= '0';
				if (GPIO_I(4) = '1') then
					state <= reset;
				end if;
				micap_wait_en <= '1';
			end if;
                      
          when rdFrame_idle =>
          GPIO_O(7 downto 4) <= "0110";                                                     
			M_AXIS_TVALID <= '0';
			micap_rd_en <= '0';
			micap_wr_en <= '0';
			micap_en <= '0';
			micap_wait_en <= '1';
			if (micap_waiting = '1') then
				state <= rdFrame_in;
				micap_wait <= '1';
			end if;
			
          when rdFrame_in =>
          GPIO_O(7 downto 4) <= "0111";                                                               
          	if(GPIO_I(0) = '1') then 
				S_AXIS_TREADY <= '1';
				if (S_AXIS_TVALID = '1') then
				  wr_en <= '1';
				  sum  <= std_logic_vector(unsigned(S_AXIS_TDATA));
				  if (rdFrame_nr_of_reads = 0) then
					state <= trigger_read;
					micap_wait <= '0';      
					wr_en <= '0';
				  else
					rdFrame_nr_of_reads <= rdFrame_nr_of_reads - 1;
				  end if;
				end if;
			end if;

          when trigger_read =>  
          GPIO_O(7 downto 4) <= "1000";                                                                           
			micap_rd_en <= '1';
			micap_wr_en <= '0';
			micap_en <= '1';
			micap_wait_en <= '0';
			state <= rdFrame_wait;
			
          when rdFrame_wait => --micap done
          GPIO_O(7 downto 4) <= "1001";                                                                           
			if (micap_rd_wr_done = '1') then
				state <= rdFrame_out;
				micap_read_done <= '1';
				micap_rd_en <= '0';
				micap_wr_en <= '0';
				micap_wait_en <= '1';
			end if;
			              
         when rdFrame_out =>
          GPIO_O(7 downto 4) <= "1010";                                                                                    
			S_AXIS_TREADY <= '0';
			if(GPIO_I(4) = '1') then 
			  M_AXIS_TVALID <= '1';
				if (M_AXIS_TREADY = '1') then
				rd_en <= '1';
				  if (rdFrame_nr_of_writes = 0) then
					state <= reset;
					tlast <= '1';
					micap_en <= '0';
					rd_en <= '0';
				  else
					rdFrame_nr_of_writes <= rdFrame_nr_of_writes - 1;
				  end if;
				end if;
			end if;
            
        end case;
      end if;
    end if;
   end process The_SW_accelerator;

U1: icap_controller
  PORT MAP (
--Inputs
	i_clk 				=> ACLK,
	rst_ibuff 			=> buffer_reset,
	i_ibuff_data 		=> sum,
	wr_en_ibuff 		=> wr_en,  --Write enable: input buffer write control of the MiCAP
	rd_en_obuff 		=> rd_en,  --Read enable: output buffer read control of the MiCAP
	i_icap_rd_en 		=> micap_rd_en,
	i_icap_wr_en 		=> micap_wr_en,
	i_micap_en 			=> micap_en,	
	wait_en				=> micap_wait_en,	
	i_rst 				=> micap_reset,

--Outputs
	o_config_buff_full 	=> buffer_full,
	o_icap_en 	   		=> micap_en_o,
	o_icap_data	   		=> dout,
	o_icap_wr_rd_done  	=> micap_rd_wr_done,
	empty_ibuff 		=> empty_ibuff,  
	o_icap_waiting 	   	=> micap_waiting,	 	
	empty_obuff 		=> empty_obuff   
); 
	
end architecture EXAMPLE;
