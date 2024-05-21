#
#  File Name:         testbench.vhd
#  Design Unit Name:  testbench
#
#  Maintainer:        OSVVM Authors
#  Contributor(s):
#     Guy Eschemann   (original Author)
#
#  Description:
#    Setting up local paths for testbenches
#
#  Revision History:
#    Date      Version    Description
#    06/2022   2022.06    Initial version
#
#  This file is part of OSVVM.
#
#  Copyright (c) 2022 Guy Escheman
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
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
