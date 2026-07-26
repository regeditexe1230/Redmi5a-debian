
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/io.h>

MODULE_LICENSE("GPL");

static int __init mclk_fix_init(void)
{
    void __iomem *base;
    u32 val;

    pr_info("mclk_fix: setting gpio27 to cam_mclk1\n");

    base = ioremap(0x101B000, 0x1000);
    if (!base) {
        pr_err("mclk_fix: ioremap failed\n");
        return -ENOMEM;
    }

    val = readl(base);
    pr_info("mclk_fix: GPIO27 CFG before = 0x%08x\n", val);

    /* Clear function bits [5:2] */
    val &= ~(0xF << 2);
    /* Set cam_mclk1 = function 46 = 0x2E -> bits[5:2] = 0xB */
    val |= (0xB << 2);

    writel(val, base);

    val = readl(base);
    pr_info("mclk_fix: GPIO27 CFG after = 0x%08x\n", val);

    iounmap(base);
    return 0;
}

static void __exit mclk_fix_exit(void)
{
    pr_info("mclk_fix: unloaded\n");
}

module_init(mclk_fix_init);
module_exit(mclk_fix_exit);

