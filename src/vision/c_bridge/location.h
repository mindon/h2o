#ifndef LOCATION_H
#define LOCATION_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    double lat;
    double lon;
    int success;
} LocationResult;

LocationResult get_current_location();

#ifdef __cplusplus
}
#endif

#endif
