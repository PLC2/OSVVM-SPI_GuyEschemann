--
--  File Name:         SpiContext.vhd
--  Design Unit Name:  SpiContext
--  OSVVM Release:     TODO
--
--  Description:
--      Context declaration for SPI verification component packages
--

context SpiContext is
    library osvvm_common;
        context osvvm_common.OsvvmCommonContext;

    library osvvm_spi;
        use osvvm_spi.SpiTbPkg.all;
        use osvvm_spi.SpiComponentPkg.all;
end context SpiContext;

