#ifdef NRI_ENABLE_AMDAGS

#ifndef NRI_ENABLE_D3D12_SUPPORT
#error "AMD AGS Requires D3D12 support to be enabled"
#endif //NRI_ENABLE_D3D12_SUPPORT

#include "directx/d3dcommon.h"
#endif //NRI_ENABLE_AMDAGS

#ifdef NRI_ENABLE_NVAPI
//#include "disable_sal.h"
#include "nvapi.h"
#endif //NRI_ENABLE_NVAPI

#ifdef NRI_ENABLE_AMDAGS

//Must include after d3d
#include <ole2.h>
#include "amd_ags.h"

#endif //NRI_ENABLE_AMDAGS

#include "Resources/Version.h"

#include "Include/NRI.h"
#include "Include/NRIMacro.h"

#include "Include/Extensions/NRIDeviceCreation.h"
#include "Include/Extensions/NRIHelper.h"
#include "Include/Extensions/NRIImgui.h"
#include "Include/Extensions/NRILowLatency.h"
#include "Include/Extensions/NRIMeshShader.h"
#include "Include/Extensions/NRIRayTracing.h"
#include "Include/Extensions/NRIStreamer.h"
#include "Include/Extensions/NRISwapChain.h"
#include "Include/Extensions/NRIUpscaler.h"
#include "Include/Extensions/NRIWrapperD3D11.h"
#include "Include/Extensions/NRIWrapperD3D12.h"
#include "Include/Extensions/NRIWrapperVK.h"
