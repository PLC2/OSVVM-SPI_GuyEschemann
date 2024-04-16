library osvvm_spi

analyze  OsvvmTestCommonPkg.vhd
analyze  TestCtrl_e.vhd
analyze  TbSpi.vhd

SetSaveWaves
RunTest  TbSpi_SendGet0.vhd
RunTest  TbSpi_SendGet1.vhd
RunTest  TbSpi_SendGet2.vhd
RunTest  TbSpi_SendGet3.vhd

RunTest  TbSpi_CtrlRx0.vhd
RunTest  TbSpi_CtrlRx1.vhd
RunTest  TbSpi_CtrlRx2.vhd
RunTest  TbSpi_CtrlRx3.vhd
