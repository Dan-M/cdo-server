/*
 * Copyright (c) 2014 Robert Blust (Z�rich, Switzerland) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 * 
 * Contributors:
 *    Robert Blust - initial API and implementation
 */
package ch.flatland.cdo.service.repoaccess

import ch.flatland.cdo.util.EMF
import ch.flatland.cdo.util.FlatlandException
import ch.flatland.cdo.util.Request
import ch.flatland.cdo.util.Response
import ch.flatland.cdo.util.View
import java.util.List
import javax.servlet.http.HttpServletRequest
import javax.servlet.http.HttpServletResponse
import org.eclipse.emf.cdo.CDOObject
import org.eclipse.emf.cdo.common.security.NoPermissionException
import org.eclipse.emf.cdo.eresource.CDOResource
import org.eclipse.emf.cdo.view.CDOView
import org.slf4j.LoggerFactory

class Delete {

	val logger = LoggerFactory.getLogger(this.class)

	val extension Request = new Request
	val extension Response = new Response
	val extension View = new View
	val extension EMF = new EMF

	def void run(HttpServletRequest req, HttpServletResponse resp) {

		val extension JsonConverter = req.createJsonConverter

		val view = SessionFactory.getCDOSession(req).openTransaction
		var String jsonString = null

		try {
			logger.debug("Run for '{}'", req.userId)

			val requestedObject = view.safeRequestResource(req) as CDOObject

			logger.debug("Object '{}' loaded type of {}", requestedObject.cdoID, requestedObject.eClass.type)

			requestedObject.safeCanWrite

			try {
				if (requestedObject instanceof CDOResource) {
					val resource = requestedObject
					if (resource.eContents.size > 0) {
						throw new FlatlandException(
							'''Resource '�requestedObject.cdoID�' cannot be deleted cause not empty''',
							HttpServletResponse.SC_CONFLICT)
					}
				}

				view.xRrefsDelete(requestedObject)

			} catch (NoPermissionException npe) {
				throw new FlatlandException(npe.message, HttpServletResponse.SC_FORBIDDEN)
			}

			view.commit

			// now transform manipulated object to json for the reponse			
			jsonString = JsonConverter.okToJson

		} catch (FlatlandException e) {
			resp.status = e.httpStatus
			jsonString = e.safeToJson
			logger.error("Request failed", e)
		} finally {
			if (!view.closed) {
				view.close
			}
		}
		resp.writeResponse(req, jsonString)
	}

	def private xRrefsDelete(CDOView view, CDOObject cdoObject) {
		val suspects = newArrayList
		suspects.add(cdoObject)
		suspects.addAll(cdoObject.eAllContents.toList)

		suspects.forEach [
			view.queryXRefs(it as CDOObject, emptyList).forEach [
				val source = it.sourceObject
				val sourceFeature = it.sourceFeature
				val sourceIndex = it.sourceIndex
				logger.debug("Found xref feature '{}', source '{}', index '{}'", sourceFeature.name, source, sourceIndex)
				if (sourceFeature.isMany) {
					(source.eGet(sourceFeature) as List<Object>).remove(sourceIndex)
				} else {
					source.eUnset(sourceFeature)
				}
			]
		]
		val container = cdoObject.eContainer
		if (container == null) {
			// must be a CDOResource Node
			val resource = cdoObject.cdoResource
			resource.contents.remove(cdoObject)
		} else {
			val containingFeature = cdoObject.eContainingFeature
			if (containingFeature.isMany) {
				(container.eGet(containingFeature) as List<Object>).remove(cdoObject)
			} else {
				container.eUnset(containingFeature)
			}
		}
	}
}
