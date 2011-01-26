<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:template match="entry">
    <div>
      <xsl:apply-templates select="form|gramGrp"/>
    </div>
    <xsl:apply-templates select="sense"/>
  </xsl:template>

  <xsl:template match="form">
    <xsl:apply-templates select="orth"/>
  </xsl:template>

  <xsl:template match="gramGrp">
    <xsl:apply-templates select="itype|gen"/>
  </xsl:template>

  <xsl:template match="sense">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="text()">
    <xsl:value-of select="normalize-space(string(.))"/>
  </xsl:template>

</xsl:stylesheet>
