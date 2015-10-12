//WARNING: Don't edit. Automatically regenerated file (TLUT flow)
#include "xil_testmem.h"
#define NUMBER_OF_INSTANCES 1
#define NUMBER_OF_TLUTS_PER_INSTANCE 32

#ifndef _lutlocation_type_H
#define _lutlocation_type_H
typedef struct {
	u32 lutCol;
	u32 lutRow;
	u8 sliceType;
	u8 lutType;
} lutlocation;
#endif


#define XHI_CLB_SLICEM_EVEN 0
#define XHI_CLB_SLICEL_ODD 1
#define XHI_CLB_SLICEL_EVEN 2
#define XHI_CLB_LUT_A6LUT 0
#define XHI_CLB_LUT_B6LUT 1
#define XHI_CLB_LUT_C6LUT 2
#define XHI_CLB_LUT_D6LUT 3

extern const lutlocation location_array[NUMBER_OF_INSTANCES][NUMBER_OF_TLUTS_PER_INSTANCE];

