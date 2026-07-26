#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/i2c.h>
#include <linux/delay.h>

static int __init test_i2c_init(void) {
    struct i2c_adapter *adap;
    struct i2c_client *client = NULL;
    unsigned char buf[2] = {0x01, 0x03}; // register 0x0103 (high byte first for OV)
    int ret;

    pr_info("test_i2c: init\n");

    /* Try to get CCI adapter */
    adap = i2c_get_adapter(5);
    if (!adap) { pr_err("test_i2c: no adapter 5\n"); return -ENODEV; }

    /* Scan for OV8865 at known addresses */
    int addrs[] = {0x20, 0x36, 0x3c, 0x10, 0x6c};
    int i;
    for (i = 0; i < 5; i++) {
        unsigned char probe_buf[2] = {(addrs[i] << 1) & 0xFE, 0x30}; // OV uses 16-bit reg: 0x300a
        struct i2c_msg msg = {
            .addr = addrs[i],
            .flags = I2C_M_TEN, // Wait, OV8865 uses 7-bit? No, regular I2C
            .len = 2,
            .buf = probe_buf,
        };
        msg.flags = 0; // Write
        msg.buf[0] = 0x30; msg.buf[1] = 0x0a;
        msg.len = 2;

        struct i2c_msg msgs[2] = {
            { .addr = addrs[i], .flags = 0, .len = 2, .buf = probe_buf },
            { .addr = addrs[i], .flags = I2C_M_RD, .len = 2, .buf = probe_buf },
        };

        ret = i2c_transfer(adap, msgs, 2);
        pr_info("test_i2c: probe addr 0x%02x -> %d\n", addrs[i], ret);
    }

    i2c_put_adapter(adap);
    return 0;
}

static void __exit test_i2c_exit(void) { pr_info("test_i2c: exit\n"); }
module_init(test_i2c_init);
module_exit(test_i2c_exit);
MODULE_LICENSE("GPL");
