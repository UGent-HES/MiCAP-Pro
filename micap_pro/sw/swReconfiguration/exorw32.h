//WARNING: Don't edit. Automatically regenerated file (TLUT flow)
#include "xil_assert.h"
#include "locations.h"

#include <xstatus.h>
#include <xparameters.h>

#define HWICAP_DEVICEID       XPAR_HWICAP_0_DEVICE_ID
#define XHI_TARGET_DEVICEID   XHI_READ_DEVICEID_FROM_ICAP
#define LUT_CONFIG_WIDTH   64
#define NUMBER_OF_PARAMETERS  32

void evaluate(u8 parameter[NUMBER_OF_PARAMETERS], u8 output[NUMBER_OF_TLUTS_PER_INSTANCE][LUT_CONFIG_WIDTH]);
