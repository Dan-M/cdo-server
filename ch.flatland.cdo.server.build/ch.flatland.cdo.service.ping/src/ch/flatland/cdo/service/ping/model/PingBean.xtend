package ch.flatland.cdo.service.ping.model

import org.eclipse.xtend.lib.annotations.Data

@Data class PingBean {
	String status
	String name
	String version
}