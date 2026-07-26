#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/delay.h>
#include <linux/platform_device.h>
#include <linux/of_platform.h>
#include <sound/soc.h>
#include <sound/soc-dapm.h>

static int __init dapm_fix_init(void)
{
	struct snd_soc_card *card = NULL;
	struct device_node *np;
	struct platform_device *pdev;
	int retry;

	np = of_find_compatible_node(NULL, NULL,
		"qcom,msm8916-qdsp6-sndcard");
	if (!np) {
		pr_err("dapm_fix: card node not found\n");
		return -ENODEV;
	}
	pdev = of_find_device_by_node(np);
	of_node_put(np);
	if (!pdev) {
		pr_err("dapm_fix: pdev not found\n");
		return -ENODEV;
	}
	card = platform_get_drvdata(pdev);
	if (!card) {
		pr_err("dapm_fix: card data not found\n");
		return -ENODEV;
	}
	pr_info("dapm_fix: found card '%s'\n", card->name);

	{
		struct snd_soc_dapm_route routes[] = {
			{"Speaker", NULL, "SPK_OUT"},
			{"Speaker Amp INL", NULL, "SPK_OUT"},
			{"Speaker Amp INR", NULL, "SPK_OUT"},
		};
		snd_soc_dapm_add_routes(&card->dapm, routes, ARRAY_SIZE(routes));
	}

	/* wait for codec widgets to stabilize */
	msleep(1500);

	for (retry = 0; retry < 20; retry++) {
		struct snd_soc_dapm_widget *w;

		snd_soc_dapm_force_enable_pin(&card->dapm, "Speaker");
		snd_soc_dapm_sync(&card->dapm);

		/* verify Speaker widget is actually powered */
		for_each_card_widgets(card, w) {
			if (strcmp(w->name, "Speaker") == 0) {
				if (w->power) {
					pr_info("dapm_fix: Speaker powered OK (retry=%d)\n", retry);
					return 0;
				}
				break;
			}
		}
		pr_info("dapm_fix: Speaker not powered, retry=%d\n", retry);
		msleep(500);
	}

	pr_warn("dapm_fix: Speaker still not powered after 20 retries\n");
	return 0;
}

static void __exit dapm_fix_exit(void)
{
	pr_info("dapm_fix: unloaded\n");
}

module_init(dapm_fix_init);
module_exit(dapm_fix_exit);
MODULE_LICENSE("GPL");
