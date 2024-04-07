--
--  File Name:         SpiPeripheral.vhd
--  Design Unit Name:  SPI
--  OSVVM Release:     TODO
--
--  Maintainer:        Guy Eschemann  email: guy@noasic.com
--  Contributor(s):
--     Guy Eschemann   guy@noasic.com
--
--  Description:
--      SPI Controller Verification Component

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use std.textio.all;


library OSVVM;
    context OSVVM.OsvvmContext;

library osvvm_common;
    context osvvm_common.OsvvmCommonContext;
    use osvvm.ScoreboardPkg_slv.all;

use work.SpiTbPkg.all;

entity SpiPeripheral is
    generic(
        MODEL_ID_NAME : string      := "";
        SPI_MODE      : SpiModeType := 0
    );
    port(
        TransRec : inout  SpiRecType;
        SCLK     : in     std_logic;
        CSEL     : in     std_logic;
        PICO     : in     std_logic;
        POCI     : out    std_logic
    );
end entity SpiPeripheral;

architecture blocking of SpiPeripheral is

    ----------------------------------------------------------------------------
    -- Constants
    ----------------------------------------------------------------------------

    -- Use MODEL_ID_NAME Generic if set, otherwise,
    -- use model instance label (preferred if set as entityname_1)
    constant MODEL_INSTANCE_NAME : string := IfElse(MODEL_ID_NAME'length > 0,
                                                    MODEL_ID_NAME,
                                                    to_lower(
                                                    PathTail(
                                                    SpiPeripheral'PATH_NAME
                                                    )));

    ----------------------------------------------------------------------------
    -- Signals
    ----------------------------------------------------------------------------
    -- Model Signals
    signal ModelID              : AlertLogIDType;
    signal TransmitFifo         : osvvm.ScoreboardPkg_slv.ScoreboardIDType;
    signal ReceiveFifo          : osvvm.ScoreboardPkg_slv.ScoreboardIDType;
    signal TransmitRequestCount : integer              :=  0;
    signal TransmitDoneCount    : integer              :=  0;
    signal ReceiveCount         : integer              :=  0;
    -- SPI Mode Signals
    signal OptSpiMode           : SpiModeType          :=  SPI_MODE;
    signal InOnRise             : boolean              :=  FALSE;

begin

    ----------------------------------------------------------------------------
    --  Initialize SPI Peripheral Entity
    ----------------------------------------------------------------------------
    Initialize : process
        variable ID : AlertLogIDType;
    begin
        ID                 := NewID(MODEL_INSTANCE_NAME);
        ModelID            <= ID;
        TransRec.BurstFifo <= NewID("BurstFifo", ID,
                                    Search => PRIVATE_NAME);
        TransmitFifo       <= NewID("TransmitFifo", ID,
                                    ReportMode => DISABLED,
                                    Search     => PRIVATE_NAME);
        ReceiveFifo        <= NewID("ReceiveFifo", ID,
                                    ReportMode => DISABLED,
                                    Search => PRIVATE_NAME);
        wait;
    end process Initialize;

    ----------------------------------------------------------------------------
    --  Transaction dispatcher
    ----------------------------------------------------------------------------

    TransactionDispatcher : process
        alias Operation : StreamOperationType is TransRec.Operation;
        variable RxData : std_logic_vector(7 downto 0);
        variable TxData : std_logic_vector(7 downto 0);

    begin
        -- Wait for ModelID to get set
        wait for 0 ns;

        TransactionDispatcherLoop : loop
            WaitForTransaction(
                Clk => SpiClk,
                Rdy => TransRec.Rdy,
                Ack => TransRec.Ack
            );

            case Operation is
                when SEND =>
                    Log(ModelID, "SEND", DEBUG);
                    --
                    TxData := SafeResize(TransRec.DataToModel, TxData'length);
                    Push(TransmitFifo, TxData);
                    Increment(TransmitRequestCount);
                    wait for 0 ns; -- Ensure increment
                    wait until TransmitRequestCount = TransmitDoneCount;

                when SEND_ASYNC =>
                    Log(ModelID, "SEND_ASYNC", DEBUG);
                    --
                    TxData := SafeResize(TransRec.DataToModel, TxData'length);
                    Push(TransmitFifo, TxData);
                    Increment(TransmitRequestCount);

                when GET =>
                    Log(ModelID, "GET", DEBUG);
                    --
                    if Empty(ReceiveFifo) then
                        WaitForToggle(ReceiveCount);
                    end if;
                    RxData := Pop(ReceiveFifo);
                    TransRec.DataFromModel <= SafeResize(RxData,
                                                         TransRec.DataFromModel
                                                        );

                when WAIT_FOR_TRANSACTION =>
                    Log(ModelID, "WAIT_FOR_TRANSACTION", DEBUG);
                    --
                    if Empty(ReceiveFifo) then
                        WaitForToggle(ReceiveCount);
                    end if;

                when WAIT_FOR_CLOCK =>
                    Log(ModelID, "WAIT_FOR_CLOCK", DEBUG);
                    --
                    WaitCycles := TransRec.IntToModel;
                    -- Make this wait for X num of actual sclk cycles

                when GET_ALERTLOG_ID =>
                    Log(ModelID, "GET_ALERTLOG_ID", DEBUG);
                    --
                    TransRec.IntFromModel <= ModelID;

                when GET_TRANSACTION_COUNT =>
                    Log(ModelID, "GET_TRANSACTION_COUNT", DEBUG);
                    --
                    TransRec.IntFromModel <= TransmitDoneCount;

                when SET_MODEL_OPTIONS =>
                    case TransRec.Options is
                        when SpiOptionType'pos(SET_SPI_MODE) =>
                        OptSpiMode <= TransRec.IntToModel;
                        -- Log SPI mode change
                        Log(ModelID, "Set SPI mode = " &
                            to_string(TransRec.IntToModel),
                            INFO);

                        when others =>
                            Alert(ModelID, OPT_ERR_MSG &
                                  to_string(SpiOptionType'val(TransRec.Options)),
                                  FAILURE);
                    end case;

                when MULTIPLE_DRIVER_DETECT =>
                    Alert(ModelID, DRV_ERR_MSG & "  Transaction # " &
                          to_string(TransRec.Rdy), FAILURE);

                when others =>
                    Alert(ModelID, "Unimplemented Transaction: " &
                          to_string(Operation), FAILURE);
            end case;

        end loop TransactionDispatcherLoop;
    end process TransactionDispatcher;

    ----------------------------------------------------------------------------
    -- SPI Peripheral Receive and Transmit Functionality
    ----------------------------------------------------------------------------
    SpiRxHandler : process
        variable RxData      : std_logic_vector(7 downto 0);
        variable TxData      : std_logic_vector(7 downto 0); -- not used yet

    begin
        wait for 0 ns;
        -- Shift in PICO data on edge per SPI Mode
        if CSEL = '0' then
            if rising_edge(SCLK) and InOnRise then
                RxData := RxData(RxData'high - 1 downto RxData'low) &
                                 PICO;
            elsif falling_edge(SCLK) and not InOnRise then
                RxData := RxData(RxData'high - 1 downto RxData'low) &
                                PICO;
            end if;
        end if;
        -- Push RX data on CSEL rise / Update SPI Mode on CSEL fall
        if rising_edge(CSEL) then
            Push(ReceiveFifo, RxData);
            Increment(ReceiveCount);
        elsif falling_edge(CSEL) then
            InOnRise <= TRUE when OptSpiMode = 0 or OptSpiMode = 3 else FALSE;
        end if;

    end process SpiRxHandler;

    SpiTxHandler : process
    begin
        if TRUE then
        end if;
    end process SpiTxHandler;
end architecture blocking;
