<%@page contentType="text/html"
	import="java.net.*,java.util.*,java.io.*"%>

<html>
<head>
<title>JBoss-Cloud node info</title>
</head>
<body>

<%
	//borrowed from jmx-console	

	String bindAddress = "";
	String serverName = "";
	try {
		bindAddress = System.getProperty("jboss.bind.address", "");
		serverName = System.getProperty("jboss.server.name", "");
	} catch (SecurityException se) {
	}

	String hostname = "";
	try {
		hostname = InetAddress.getLocalHost().getHostName();
	} catch (IOException e) {
	}

	String hostInfo = hostname;
	if (!bindAddress.equals("")) {
		hostInfo = hostInfo + " (" + bindAddress + ")";
	}
%>


<table>
	<%
		if (bindAddress.length() > 0) {
	%>
	<tr>
		<td>JBoss Address:</td>
		<td><%=bindAddress%></td>
	</tr>

	<%
		}
		if (serverName.length() > 0) {
	%>
	<tr>
		<td>JBoss profile:</td>
		<td><%=serverName%></td>
	</tr>
	<%
		}
	%>
	<tr>
		<td>Server name:</td>
		<td><%=request.getServerName()%></td>
	</tr>
	<tr>
		<td>Server port:</td>
		<td><%=request.getServerPort()%></td>
	</tr>
	<tr>
		<td>Remote address:</td>
		<td><%=request.getRemoteAddr()%></td>
	</tr>

</table>

</body>
</html>
