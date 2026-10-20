# Units of Measure

## Power
`CommonOPF` does not impose a specific unit for power such as MW or kW. However, methods for
retrieving values in per-unit are available, which divide power values provided by users by the
`Network.Sbase` value. For example, a user can input a `Generator.pmax` in MW or watts if they wish. 

Note that `dss_to_Network` *does* convert the kW and kVar values for OpenDSS loads to watts and vars
so that units are consistent for the returned `Network.Vbase` and `Network.Sbase` values that are
interpreted from the OpenDSS data (i.e. no scaling is necessary when using `Network.Zbase`)