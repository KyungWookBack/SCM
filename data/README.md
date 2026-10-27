# Data

`Final_Data.xlsx` has one sheet per country. The analysis reads ten of them (Argentina, Brazil, Chile, Greece, India, Mexico, NorthKorea, Portugal, Singapore, Spain). Four more sheets are included but unused: Japan and South Korea were excluded for the reasons given in Section 3.2 of the paper, and Philippines and Thailand were set aside during donor selection because their pre-1945 trajectories (American colonial rule and no colonization, respectively) were judged too different from North Korea’s to serve as comparisons. Rows are indicators, columns are years 1911–1943 and 1954–2013. MD5: `0db5d958f630a46b2e4d7d9ad640e586`.

Indicators used by the analysis:

| Indicator | Source | Pre-1944 coverage |
|---|---|---|
| GDP per Capita (2011 international $) | Maddison Project Database 2020 | annual |
| Population (thousands) | Clio Infra; for North Korea, Government-General of Korea *Statistical Yearbook* | annual |
| Average Years of Education, Educational Inequality Gini | Clio Infra | 1920, 1930, 1940 (Gini near-annual) |
| Cropland per Capita, SO2 Emissions per Capita | Clio Infra | 1920, 1930, 1940 |
| Total Cattle, Pigs, Goats | Clio Infra | 1920, 1930, 1940 |

## North Korean series

Colonial-period population was obtained by subtracting the southern provinces from peninsula totals in the Government-General yearbook. The 1911–1943 northern GDP per capita series is a regional allocation of peninsula GDP; we did not keep a full record of the allocation steps at the time, so that construction is not reproducible from this file. For 1954–1989, growth rates from Cho and Kim (2020, Bank of Korea WP 2020-17) were chained to a Maddison benchmark. The paper discusses these provenance limits in Section 3.1.

## Terms

The Maddison Project Database 2020 is released under CC BY 4.0. Clio Infra data are redistributed from its public database; see clio-infra.eu for terms. The Government-General yearbook is in the public domain. Please cite the original sources if you reuse this file.