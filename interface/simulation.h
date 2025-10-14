#include <stdint.h>
#include <stdbool.h>

/** starting_config, starting_state **
 *
 * - buf is writable memory;
 * - len points to the size of buf (in bytes).
 *
 * The return value says if it was successfull (true) or not (false)
 *
 * The function may write to len.
 *
 * If the return is true:
 *   the function succeeded;
 *   if (*len) is smaller or equal then the original (*len)
 *     (*len) indicates how many bytes the config takes
 *   else
 *     (*len) indicates how many bytes the config whished to take,
 *     i.e, the function would like to have more memory
 * else
 *   the function failed;
 *   if (*len) is smaller or equal then the original (*len)
 *     there was an internal error,
 *     the caller should abort
 *   else
 *     there is not enough memory,
 *     (*len) indicates how many bytes the config needs
 */
bool starting_config(uint8_t buf[], uint64_t *len);
bool starting_state(
    const uint8_t config[], uint64_t config_len,
    uint8_t buf[], uint64_t *len
);

bool state_step(
    const uint8_t input[], uint64_t input_len,
    const uint8_t config[], uint64_t config_len,
    const uint8_t state[], uint64_t state_len,
    uint8_t out_state[], uint64_t *out_state_len
);
