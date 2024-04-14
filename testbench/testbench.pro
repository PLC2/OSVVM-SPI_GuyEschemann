library osvvm_spi

analyze  OsvvmTestCommonPkg.vhd
analyze  TestCtrl_e.vhd
analyze  TbSpi.vhd

SetSaveWaves
RunTest  TbSpi_SendGet3.vhd
